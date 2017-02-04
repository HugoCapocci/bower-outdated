process.bin = process.title = 'bower-outdated'

_ = require 'lodash'
bower = require 'bower'
Promise = require 'bluebird'
#see https://en.wikipedia.org/wiki/ANSI_escape_code
colors = require 'ansicolors'
table = require 'text-table'
semver = require 'semver'
fs = require 'fs'

#TODO specify path
path = './'

#search wanted version (in conf)
bowerConf = require path + 'bower.json'

checkActualVersions = ->
  src = path + 'bower_components'
  try
    bowerRc = JSON.parse fs.readFileSync path + '.bowerrc'
    src = bowerRc.directory
  catch
    console.log colors.red 'No .bowerrc file found, use defaut configuration'

  Promise.map bowerDependencies, (bowerDependency) ->
    new Promise (resolve, reject) ->
      fs.readFile src + '/' + bowerDependency.name + '/.bower.json', (error, data) ->
        return reject error if error
        bowerDependency.actualVersion = JSON.parse(data).version
        resolve()

ansiTrim = (str) ->
  r = new RegExp '\x1b(?:\\[(?:\\d+[ABCDEFGJKSTm]|\\d+;\\d+[Hfm]|\\d+;\\d+;\\d+m|6n|s|u|\\?25[lh])|\\w)', 'g'
  str.replace r, ''

makePretty = ({name, actualVersion, wantedVersion, latestVersion}) ->
  columns = [
    name
    actualVersion || 'MISSING'
    wantedVersion
    latestVersion
  ]
  columns[0] = colors[if semver.satisfies(actualVersion, wantedVersion) then 'yellow' else 'red'] columns[0]
  columns[2] = colors.green semver.validRange columns[2]
  columns[3] = colors.magenta columns[3]
  columns

bowerDependencies = _.map bowerConf.dependencies, (value, key) ->
  name: key
  wantedVersion: value
bowerDependencies = bowerDependencies.concat _.map bowerConf.devDependencies, (value, key) ->
  name: key
  wantedVersion: value

Promise.map bowerDependencies, (bowerDependency) ->
  new Promise (resolve, reject) ->
    bower.commands.info bowerDependency.name
    .on 'end', (results) ->
      bowerDependency.latestVersion = results.latest.version
      resolve()
.then ->
  checkActualVersions()
.then ->
  headers = [
    'Package'
    'Current'
    'Wanted'
    'Latest'
  ]
  outTable = [headers].concat bowerDependencies.map makePretty
  tableOpts =
    align: ['l', 'r', 'r', 'r']
    stringLength: (s) -> ansiTrim(s).length
  console.log table outTable, tableOpts
  return
