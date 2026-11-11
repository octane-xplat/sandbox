const path = require('node:path')

module.exports = {
	hooks: require('./octane-config.cjs')(
		path.join(__dirname, 'octane-xplat'),
		path.join(__dirname, '../package.json'),
	),
}
