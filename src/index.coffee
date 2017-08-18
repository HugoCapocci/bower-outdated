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
      name = if bowerDependency.installedName then bowerDependency.installedName else bowerDependency.name
      file = src + '/' + name + '/.bower.json'
      fs.readFile file, (error, data) ->
        unless error
          bowerDependency.actualVersion = JSON.parse(data).version
        resolve()

ansiTrim = (str) ->
  r = new RegExp '\x1b(?:\\[(?:\\d+[ABCDEFGJKSTm]|\\d+;\\d+[Hfm]|\\d+;\\d+;\\d+m|6n|s|u|\\?25[lh])|\\w)', 'g'
  str.replace r, ''

makePretty = ({name, wantedVersion, latestVersion}) ->
  columns = [
    name
    wantedVersion
    latestVersion
  ]
  weWantLatestVersion = semver.satisfies(latestVersion, wantedVersion)
  columns[0] = colors[if weWantLatestVersion then 'green' else 'red'] columns[0]
  if columns[1] is 'git'
    columns[1] = colors.green columns[1]
  else
    columns[1] = colors[if weWantLatestVersion then 'green' else 'red'] semver.validRange columns[1]
  columns[2] = colors[if weWantLatestVersion then 'green' else 'magenta'] columns[2]
  if !weWantLatestVersion then columns[3] = colors['white'] "New Version Available"
  columns

mapDependencyFromConfig =  (value, key) ->
  sharpIndex = value.indexOf '#'
  if sharpIndex isnt -1
    if _.startsWith value, 'git'
      value = 'git'
    else
      installedName = key
      key = value.substring 0, sharpIndex
      value = value.substring sharpIndex + 1
  name: key
  wantedVersion: value
  installedName: installedName if installedName?

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
    'Version we want'
    'Latest Available'
    'Action Required'
  ]
  outTable = [headers].concat _.compact bowerDependencies.map makePretty
  tableOpts =
    align: ['l', 'r', 'r', 'l']
    stringLength: (s) -> ansiTrim(s).length
  console.log table outTable, tableOpts
  return
.catch (error) ->
  console.error error
