process.bin = process.title = 'bower-outdated'

_ = require 'lodash'
bower = require 'bower'
Promise = require 'bluebird'
#see https://en.wikipedia.org/wiki/ANSI_escape_code
colors = require 'ansicolors'
table = require 'text-table'
semver = require 'semver'
fs = require 'fs'

#by default, only display outdated
displayAll = false

#TODO specify path from cwd in argument ?
path = process.cwd() + '/'

try
  bowerConf = require path + 'bower.json'
catch error
  console.error colors.red "Cannot find #{path}bower.json config file."
  process.exit 1

displayProcessingMessage = (message) ->
  P = ['\\', '|', '/', '-']
  x = 0
  setInterval ->
    process.stdout.write '\r' + colors.cyan(P[x++]) + ' ' + message
    x &= 3
  , 250

clearProcessingMessage = (processingMessage)->
  clearInterval processingMessage
  process.stdout.write '\r'

checkInstalledVersions = ->
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
  return if not displayAll and (actualVersion is latestVersion)
  columns = [
    name
    actualVersion || 'MISSING'
    wantedVersion
    latestVersion
  ]
  columns[0] = colors[if semver.satisfies(actualVersion, wantedVersion) then 'yellow' else 'red'] columns[0]
  if columns[2] is 'git'
    columns[2] = colors.green columns[2]
  else
    columns[2] = colors.green semver.validRange columns[2]
  columns[3] = colors.magenta columns[3]
  columns

mapDependencyFromConfig =  (value, key) ->
  name: key
  wantedVersion: if _.startsWith value, 'git' then 'git' else value

bowerDependencies = _.map bowerConf.dependencies, mapDependencyFromConfig
bowerDependencies = bowerDependencies.concat _.map bowerConf.devDependencies, mapDependencyFromConfig

processingMessage = displayProcessingMessage 'check latests dependencies'
Promise.map bowerDependencies, (bowerDependency) ->
  new Promise (resolve, reject) ->
    if bowerDependency.wantedVersion is 'git'
      bowerDependency.latestVersion = 'git'
      return resolve()
    bower.commands.info bowerDependency.name
    .on 'end', (results) ->
      bowerDependency.latestVersion = results.latest.version
      resolve()
.then ->
  clearProcessingMessage processingMessage
  processingMessage = displayProcessingMessage 'check installed dependencies'
  checkInstalledVersions()
.then ->
  clearProcessingMessage processingMessage
  headers = [
    'Package'
    'Current'
    'Wanted'
    'Latest'
  ]
  outTable = [headers].concat _.compact bowerDependencies.map makePretty
  tableOpts =
    align: ['l', 'r', 'r', 'r']
    stringLength: (s) -> ansiTrim(s).length
  console.log table outTable, tableOpts
  return
.catch (error) ->
  console.error error
