#!/usr/bin/env python3
"""Release-build, native trace capture, and app-scoped grid frame timing reports."""
from __future__ import annotations

import argparse
import csv
from collections import Counter
import hashlib
import io
import json
import math
import os
from pathlib import Path
import shutil
import statistics
import subprocess
import sys
import tempfile
import time
import uuid
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
PACKAGE = 'org.octanexplat.sandbox'
IOS_PROCESS = 'sandbox'
MARKER = 'GridProfile'
TRACE_SECONDS = 26


def run(args, *, env=None, input=None, timeout=180, log=None, live=False):
    if live:
        with open(log, 'w') as output:
            result = subprocess.run([str(a) for a in args], cwd=ROOT, env=env,
                                    stdout=output, stderr=output, text=True, timeout=timeout)
        if result.returncode:
            raise RuntimeError(f'{args[0]} failed (exit {result.returncode}); see {log}')
        return ''
    result = subprocess.run([str(a) for a in args], cwd=ROOT, env=env, input=input,
                            text=True, capture_output=True, timeout=timeout)
    if log:
        Path(log).write_text(result.stdout + result.stderr)
    if result.returncode:
        raise RuntimeError(f'{args[0]} failed (exit {result.returncode}); ' +
                           (f'see {log}' if log else (result.stderr or result.stdout)[-1200:]))
    return result.stdout


def save(path, value):
    Path(path).write_text(json.dumps(value, indent=2) + '\n')


def quantile(values, fraction):
    """Nearest-rank percentile; preserve spikes instead of interpolating them away."""
    values = sorted(values)
    return values[max(0, math.ceil(len(values) * fraction) - 1)] if values else None


def distribution(values):
    return {key: quantile(values, fraction) for key, fraction in
            [('p50', .5), ('p95', .95), ('p99', .99), ('max', 1)]}


def summarize_android(rows, window):
    if not rows:
        raise ValueError('No app frames inside GridProfile; refusing a zero-jank result')
    # Each logical app frame can appear on multiple layers. Count the token once.
    frames = {}
    for row in rows:
        token = row['surface_frame_token']
        if token in frames:
            raise ValueError('Duplicate frame token: SQL must deduplicate app layers')
        frames[token] = row
    janky = sum(row['jank_type'] not in ('None', '') for row in rows)
    dropped = sum(row['present_type'] == 'Dropped Frame' for row in rows)
    durations = [int(row['dur']) / 1e6 for row in rows]
    overruns = [float(row['overrun_ns']) / 1e6 for row in rows if row['overrun_ns'] != '']
    return {
        'frame_count': len(frames),
        'janky_frame_percent': 100 * janky / len(frames),
        'app_deadline_missed_frame_percent': 100 * sum('App Deadline Missed' in row['jank_type'] for row in rows) / len(frames),
        'jank_type_counts': dict(Counter(flag.strip() for row in rows for flag in row['jank_type'].split(',') if flag.strip() not in ('None', ''))),
        'dropped_frame_percent': 100 * dropped / len(frames),
        'app_frame_production_ms': distribution(durations),
        'frame_overrun_ms': distribution(overruns),
        'window_seconds': (window[1] - window[0]) / 1e9,
        'definition': 'FrameTimeline app frame production duration, including GPU; not display cadence or CPU-only time.',
    }


def read_xctrace(path):
    """Resolve xctrace's shared cell references by raw value, never rounded fmt text."""
    root = ET.parse(path).getroot()
    ids = {node.get('id'): node for node in root.iter() if node.get('id')}

    def value(node):
        visited = set()
        while node.get('ref'):
            ref = node.get('ref')
            if ref in visited or ref not in ids:
                raise ValueError(f'Invalid xctrace reference: {ref}')
            visited.add(ref)
            node = ids[ref]
        if node.tag == 'process' and node.get('fmt'):
            return node.get('fmt')
        return ''.join(node.itertext()).strip() or node.get('fmt', '')

    tables = []
    for table in root.iter('schema'):
        parent = next((p for p in root.iter() if table in list(p)), None)
        if parent is None:
            continue
        columns = [col.findtext('mnemonic') or col.get('mnemonic') or col.get('name') for col in table.findall('./col')]
        rows = []
        for row in parent.findall('./row'):
            cells = list(row)
            if len(cells) != len(columns):
                raise ValueError('xctrace column/cell count mismatch')
            rows.append(dict(zip(columns, [value(cell) for cell in cells])))
        tables.append((table.get('name', ''), rows))
    return tables


def field(row, aliases, *, required=True):
    normalized = {str(k).lower().replace('_', '-'): v for k, v in row.items()}
    for name in aliases:
        if name in normalized:
            return normalized[name]
    if required:
        raise ValueError(f'Unsupported xctrace columns: {list(row)}; need {aliases}')
    return None


def interval(row):
    # Raw xctrace time cells are nanoseconds. Reject formatted/non-numeric values.
    start = int(field(row, ['start-time', 'start', 'timestamp', 'time']))
    duration = int(field(row, ['duration', 'hitch-duration', 'frame-lifetime', 'frame-duration']))
    return start, start + duration


def summarize_ios(tables):
    markers, frames, hitches = [], [], []
    for schema, rows in tables:
        if 'signpost' in schema:
            markers += [row for row in rows if field(row, ['name', 'signpost-name'], required=False) == MARKER]
        elif schema == 'hitches-frame-lifetimes':
            frames += rows
        elif schema == 'hitches':
            hitches += rows
    if not {'hitches', 'hitches-frame-lifetimes'} <= {schema for schema, rows in tables}:
        raise ValueError('Required Instruments frame/hitch schemas are missing')
    windows = [interval(row) for row in markers]
    windows = [window for window in windows if window[1] > window[0]]
    if len(windows) != 1:
        raise ValueError('Expected exactly one completed GridProfile signpost interval')
    start, end = windows[0]

    def app_rows(rows):
        result = []
        for row in rows:
            process = field(row, ['process', 'target-process'], required=True)
            if process != IOS_PROCESS and not process.startswith(IOS_PROCESS + ' ('):
                continue
            a, b = interval(row)
            if a >= start and b <= end and b > a:
                result.append((a, b))
        return result

    frame_intervals = app_rows(frames)
    hitch_intervals = app_rows(hitches)
    if not frame_intervals:
        raise ValueError('No app frame lifetimes in GridProfile; refusing a zero-hitch result')
    # Union intervals so overlapping hitch rows cannot inflate the time ratio.
    merged = []
    for a, b in sorted(hitch_intervals):
        if merged and a <= merged[-1][1]:
            merged[-1][1] = max(b, merged[-1][1])
        else:
            merged.append([a, b])
    total = sum(b - a for a, b in merged)
    return {
        'frame_count': len(frame_intervals),
        'frame_lifetime_ms': distribution([(b - a) / 1e6 for a, b in frame_intervals]),
        'hitch_count': len(hitch_intervals),
        'hitch_duration_ms': distribution([(b - a) / 1e6 for a, b in hitch_intervals]),
        'hitch_ms_per_second': total / 1e6 / ((end - start) / 1e9),
        'window_seconds': (end - start) / 1e9,
        'dropped_frame_percent': None,
        'definition': 'Instruments frame pipeline lifetime and native hitch intervals. Lifetime is not display cadence. Dropped-frame percentage is unavailable from these tables.',
    }


def revision():
    return {'commit': run(['git', 'rev-parse', 'HEAD']).strip(),
            'dirty': bool(run(['git', 'status', '--porcelain']).strip())}


def sha256(path):
    with open(path, 'rb') as source:
        digest = hashlib.sha256()
        for chunk in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def reserve(args):
    if os.environ.get('GRID_PROFILE_RESERVED') == '1':
        return False
    resources = {'native_builds': 1} if args.action == 'build' else {'exclusive': [f'device:{args.device}']}
    request = json.dumps({'resources': resources, 'purpose': f'Grid {args.platform} {args.action}'})
    child_env = {**os.environ, 'GRID_PROFILE_RESERVED': '1'}
    # No shell: device IDs and paths stay literal arguments.
    result = subprocess.run(['goddard-agent', 'resource', 'run', '--json', request, '--',
                             sys.executable, str(Path(__file__).resolve()), *sys.argv[1:]], env=child_env)
    if result.returncode:
        raise RuntimeError('Reserved profiling phase failed')
    return True


def build(args):
    args.out.mkdir(parents=True, exist_ok=False)
    env = {**os.environ, 'VITE_GRID_PROFILING': '1'}
    command = ['pnpm', f'build:{args.platform}', '--release']
    if args.platform == 'android':
        # Standard local Android development key, not a distribution credential.
        key = Path.home() / '.android/debug.keystore'
        if not key.is_file():
            raise ValueError('Missing ~/.android/debug.keystore; create a local development key before profiling')
        command += ['--key-store-path', str(key), '--key-store-password', 'android',
                    '--key-store-alias', 'androiddebugkey', '--key-store-alias-password', 'android']
        source = ROOT / 'platforms/android/app/build/outputs/apk/release/app-release.apk'
        artifact = args.out / 'grid.apk'
    else:
        command += ['--for-device']
        source = ROOT / 'platforms/ios/build/Release-iphoneos/sandbox.ipa'
        artifact = args.out / 'grid.ipa'
    run(command, env=env, timeout=900, log=args.out / 'build.log', live=True)
    shutil.copy2(source, artifact)
    save(args.out / 'build.json', {'platform': args.platform, 'configuration': 'release',
                                  'profiling_enabled': True, 'artifact': str(artifact.resolve()),
                                  'sha256': sha256(artifact), **revision()})
    print(args.out / 'build.json', flush=True)


def android_query(processor, trace, sql, destination):
    output = run([processor, 'query', '--format', 'csv', trace, sql], timeout=120,
                 log=destination.with_suffix('.query.log'))
    destination.write_text(output)
    return list(csv.DictReader(io.StringIO(output)))


def record_android(args, directory, request, artifact):
    adb = ['adb', '-s', args.device]
    if run([*adb, 'shell', 'getprop', 'ro.kernel.qemu']).strip() == '1':
        raise ValueError('A physical Android phone is required; no emulator fallback is used')
    if int(run([*adb, 'shell', 'getprop', 'ro.build.version.sdk']).strip()) < 31:
        raise ValueError('FrameTimeline requires Android API 31 or later')
    if 'showing=true' in run([*adb, 'shell', 'dumpsys', 'window', 'policy']):
        raise ValueError('Unlock the Android device before profiling')
    run([*adb, 'install', '-r', artifact], timeout=180, log=directory / 'install.log')
    package_info = run([*adb, 'shell', 'dumpsys', 'package', PACKAGE])
    if 'DEBUGGABLE' in package_info:
        raise ValueError('Installed app is debuggable; refusing a release benchmark')
    run([*adb, 'shell', 'am', 'force-stop', PACKAGE])
    remote = f'/data/misc/perfetto-traces/grid-{uuid.uuid4().hex}.pftrace'
    config = f'''buffers {{ size_kb: 32768 fill_policy: RING_BUFFER }}
duration_ms: {TRACE_SECONDS * 1000}
data_sources {{ config {{ name: "android.surfaceflinger.frametimeline" }} }}
data_sources {{ config {{ name: "linux.process_stats" process_stats_config {{ scan_all_processes_on_start: true }} }} }}
data_sources {{ config {{ name: "linux.ftrace" ftrace_config {{
  atrace_apps: "{PACKAGE}"
  atrace_categories: "gfx"
  atrace_categories: "view"
}} }} }}
'''
    (directory / 'perfetto.pbtxt').write_text(config)
    pid = run([*adb, 'shell', 'perfetto', '--background-wait', '--txt', '-c', '-', '-o', remote], input=config).strip()
    trace = directory / 'frames.pftrace'
    try:
        run([*adb, 'shell', 'am', 'start', '-W', '-n', f'{PACKAGE}/com.tns.NativeScriptActivity',
             '--es', 'GRID_PROFILE', request], log=directory / 'launch.log')
        time.sleep(TRACE_SECONDS + 1)
        run([*adb, 'pull', remote, trace], log=directory / 'pull.log')
    finally:
        if pid.isdigit():
            run([*adb, 'shell', f'kill -TERM {pid} 2>/dev/null || true'])
        run([*adb, 'shell', 'rm', '-f', remote])
    losses = android_query(args.trace_processor, trace,
        "SELECT name, value FROM stats WHERE severity='data_loss' AND value>0", directory / 'data-loss.csv')
    if losses:
        raise ValueError('Trace reports data loss; increase trace buffer before trusting the metrics')
    window_rows = android_query(args.trace_processor, trace,
        f"SELECT s.ts, s.dur FROM slice s JOIN process_track t ON s.track_id=t.id JOIN process p USING(upid) WHERE s.name='{MARKER}' AND p.name='{PACKAGE}' AND s.dur>0", directory / 'window.csv')
    if len(window_rows) != 1:
        raise ValueError('Expected exactly one completed GridProfile marker; check profileable/release build')
    start, duration = int(window_rows[0]['ts']), int(window_rows[0]['dur'])
    end = start + duration
    sql = f'''SELECT a.surface_frame_token, MIN(a.ts) AS ts, MAX(a.dur) AS dur,
 GROUP_CONCAT(DISTINCT a.jank_type) AS jank_type,
 CASE WHEN MAX(a.present_type = 'Dropped Frame') THEN 'Dropped Frame' ELSE 'Presented' END AS present_type,
 COALESCE(CAST(MAX(a.ts+a.dur-e.ts-e.dur) AS TEXT), '') AS overrun_ns
 FROM actual_frame_timeline_slice a JOIN process p USING(upid)
 LEFT JOIN expected_frame_timeline_slice e
 ON a.upid=e.upid AND a.surface_frame_token=e.surface_frame_token
 WHERE p.name='{PACKAGE}' AND a.ts>={start} AND a.ts+a.dur<={end} AND a.dur>0
 GROUP BY a.surface_frame_token'''
    (directory / 'frames.sql').write_text(sql)
    rows = android_query(args.trace_processor, trace, sql, directory / 'frames.csv')
    metadata = {'model': run([*adb, 'shell', 'getprop', 'ro.product.model']).strip(),
                'os': run([*adb, 'shell', 'getprop', 'ro.build.version.release']).strip(),
                'trace_processor': run([args.trace_processor, '--version']).strip()}
    return summarize_android(rows, (start, end)), metadata


def record_ios(args, directory, request, artifact):
    devices = run(['xcrun', 'xctrace', 'list', 'devices'])
    (directory / 'devices.txt').write_text(devices)
    online = devices.split('== Devices Offline ==')[0].split('== Simulators ==')[0]
    if args.device not in online:
        raise ValueError('Physical iPhone is offline in xctrace; reconnect it unlocked. No simulator fallback is used.')
    with tempfile.TemporaryDirectory(prefix='grid-profile-') as unpacked:
        # Preserve executable modes and framework symlinks from the signed IPA.
        run(['ditto', '-x', '-k', artifact, unpacked])
        app = Path(unpacked) / 'Payload/sandbox.app'
        run(['xcrun', 'devicectl', 'device', 'install', 'app', '--device', args.device, app],
            timeout=180, log=directory / 'install.log')
    trace = directory / 'frames.trace'
    run(['xcrun', 'xctrace', 'record', '--template', 'Animation Hitches', '--instrument', 'Points of Interest',
         '--device', args.device, '--time-limit', f'{TRACE_SECONDS}s', '--output', trace,
         '--recording-options', ROOT / 'tools/profiling/ios-recording-options.json',
         '--env', f'GRID_PROFILE={request}', '--launch', '--', PACKAGE],
        timeout=180, log=directory / 'record.log')
    toc = directory / 'toc.xml'
    run(['xcrun', 'xctrace', 'export', '--input', trace, '--toc', '--output', toc])
    root = ET.parse(toc).getroot()
    schemas = sorted({t.get('schema') for t in root.iter('table') if t.get('schema')})
    selected = [schema for schema in schemas if schema in ('hitches', 'hitches-frame-lifetimes') or 'signpost' in schema]
    all_tables = []
    for schema in selected:
        # Only generated schema identifiers are used in the XPath.
        if not all(c.isalnum() or c in '-_' for c in schema):
            raise ValueError('Unsupported xctrace schema name')
        exported = directory / f'{schema}.xml'
        run(['xcrun', 'xctrace', 'export', '--input', trace, '--xpath',
             f'/trace-toc/run[@number="1"]/data/table[@schema="{schema}"]', '--output', exported])
        all_tables += read_xctrace(exported)
    result = summarize_ios(all_tables)
    return result, {'xcode': run(['xcodebuild', '-version']).strip(), 'schemas': schemas}


def record(args):
    manifest = json.loads(args.build_manifest.read_text())
    artifact = Path(manifest['artifact'])
    if manifest.get('configuration') != 'release' or not manifest.get('profiling_enabled'):
        raise ValueError('A profiling release build manifest is required')
    if manifest['platform'] != args.platform or sha256(artifact) != manifest['sha256']:
        raise ValueError('Build platform/hash mismatch; rebuild before recording')
    if args.platform == 'android' and not args.trace_processor:
        raise ValueError('Pass --trace-processor PATH (official get.perfetto.dev/trace_processor tool)')
    args.out.mkdir(parents=True, exist_ok=False)
    request = f'{args.scenario}:{args.dataset}'
    results = []
    save(args.out / 'manifest.json', {'workload': request, 'iterations': args.iterations,
         'build': manifest, 'device': args.device, 'created_at': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
         'workload_definition': '3 s warmup, then 12 native smooth-scroll bursts at 1200 ms cadence, or six alternating jumps at 1000 ms cadence; native GridProfile interval excludes startup/warmup.',
         'no_screenshots': True})
    try:
        for index in range(args.iterations):
            directory = args.out / f'run-{index + 1}'
            directory.mkdir()
            print(f'{args.platform} {request}: run {index + 1}/{args.iterations}', flush=True)
            capture = record_android if args.platform == 'android' else record_ios
            metrics, device = capture(args, directory, request, artifact)
            expected_window = 14.4 if args.scenario == 'scroll' else 6
            if metrics['window_seconds'] < expected_window * .9:
                raise ValueError('Measurement interval ended early; refusing an interrupted workload result')
            result = {'run': index + 1, 'metrics': metrics, 'device': device}
            save(directory / 'result.json', result)
            results.append(result)
            time.sleep(2)
        summary = {'status': 'complete', 'scenario': args.scenario, 'dataset': args.dataset,
                   'platform': args.platform, 'runs': results,
                   'median_across_runs': {key: statistics.median(values) if values else None
                       for key in ['janky_frame_percent', 'app_deadline_missed_frame_percent', 'dropped_frame_percent', 'hitch_ms_per_second']
                       for values in [[r['metrics'][key] for r in results if isinstance(r['metrics'].get(key), (int, float))]]},
                   'note': 'FPS is not inferred from idle gaps or a fixed 60 Hz budget. Compare matching platform/device/build/workloads.'}
        save(args.out / 'summary.json', summary)
        lines = [f'# Grid frame timing: {args.platform} / {request}', '',
                 '| Run | Frames | Janky % | Dropped % | p95 duration ms | Hitch ms/s |',
                 '| --- | --- | --- | --- | --- | --- |']
        def display(value):
            return f'{value:.2f}' if isinstance(value, (int, float)) else 'n/a'

        for result in results:
            m = result['metrics']
            timing = m.get('app_frame_production_ms', m.get('frame_lifetime_ms'))
            lines.append(f"| {result['run']} | {m['frame_count']} | {display(m.get('janky_frame_percent'))} | {display(m.get('dropped_frame_percent'))} | {display(timing['p95'])} | {display(m.get('hitch_ms_per_second'))} |")
        lines += ['', results[0]['metrics']['definition'], '', summary['note']]
        (args.out / 'report.md').write_text('\n'.join(lines) + '\n')
        print(args.out / 'report.md', flush=True)
    except Exception as error:
        save(args.out / 'summary.json', {'status': 'failed', 'error': str(error), 'completed_runs': results})
        raise
    finally:
        installed = any(('Success' if args.platform == 'android' else 'App installed:') in path.read_text()
                        for path in args.out.glob('run-*/install.log'))
        if installed:
            try:
                if args.platform == 'android':
                    adb = ['adb', '-s', args.device]
                    run([*adb, 'shell', 'am', 'force-stop', PACKAGE])
                    run([*adb, 'shell', 'am', 'start', '-n', f'{PACKAGE}/com.tns.NativeScriptActivity'],
                        log=args.out / 'normal-launch.log')
                else:
                    run(['xcrun', 'devicectl', 'device', 'process', 'launch', '--device', args.device,
                         '--terminate-existing', PACKAGE], log=args.out / 'normal-launch.log')
            except (RuntimeError, OSError, subprocess.TimeoutExpired) as error:
                (args.out / 'restore-error.txt').write_text(str(error))
                print('Could not restore normal app launch; see restore-error.txt', file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['build', 'record'])
    parser.add_argument('platform', choices=['android', 'ios'])
    parser.add_argument('--out', required=True, type=lambda p: Path(p).expanduser().resolve(), help='New output directory; existing paths are never overwritten')
    parser.add_argument('--device', help='Explicit physical device ID; never selects or creates a simulator')
    parser.add_argument('--build-manifest', type=Path)
    parser.add_argument('--scenario', choices=['scroll', 'jump'], default='scroll')
    parser.add_argument('--dataset', choices=[1001, 10001], type=int, default=1001)
    parser.add_argument('--iterations', type=int, choices=range(1, 11), default=3)
    parser.add_argument('--trace-processor', default=os.environ.get('TRACE_PROCESSOR'))
    args = parser.parse_args()
    if args.action == 'record' and args.platform == 'android' and (args.device or '').startswith('emulator-'):
        parser.error('Use an explicit physical Android phone, not an emulator')
    if args.action == 'record' and (not args.device or not args.build_manifest):
        parser.error('record requires --device and --build-manifest')
    try:
        if not reserve(args):
            (build if args.action == 'build' else record)(args)
    except (RuntimeError, ValueError, OSError, subprocess.TimeoutExpired) as error:
        print(f'Grid profiling failed: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
