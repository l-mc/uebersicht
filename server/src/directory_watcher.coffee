paths = require 'path'
fs = require 'fs'
fsevents = require('fsevents')

module.exports = (directoryPath, callback) ->
  api = {}
  foundPaths = {}
  closed = true
  stopWatching = null;

  init = ->
    if !fs.existsSync(directoryPath)
      throw new Error "could not find #{directoryPath}"

    closed = false
    stopWatching = fsevents.watch(directoryPath, (filePath, flags, id) ->
      return if closed
      info = fsevents.getInfo(filePath, flags, id);
      switch info.event
        when 'modified', 'created'
          findFiles filePath, info.type, registerFile
        when 'deleted'
          unregisterFiles filePath
        when 'moved'
          unregisterFiles filePath
          findFiles filePath, info.type, registerFile
    )

    console.log 'watching', directoryPath

    findFiles directoryPath, 'directory', registerFile
    close

  close = ->
    closed = true
    stopWatching?()

  registerFile = (filePath) ->
    filePath = filePath.normalize()
    foundPaths[filePath] = true
    callback({
      type: 'added',
      filePath: filePath.normalize(),
      rootPath: directoryPath,
    })

  unregisterFiles = (path) ->
    path = path.normalize()
    for filePath in Object.keys(foundPaths) when filePath.indexOf(path) == 0
      callback({type: 'removed', filePath: filePath, rootPath: directoryPath})

  # recursively walks the directory tree and calls onFound for every file it
  # finds
  findFiles = (path, type, onFound) ->
    if type == 'file'
      onFound path
    else
      fs.readdir path, (err, subPaths) ->
        return console.log err if err
        for subPath in subPaths
          fullPath = paths.join(path, subPath)
          getPathType fullPath, (p, t) -> findFiles(p, t, onFound)

  # get type of path as either 'file' or 'directory'
  # callback gets called with (path, type) where path is the path passed in,
  # for convenience
  getPathType = (path, callback) ->
    fs.stat path, (err, stat) ->
      return console.log err if err
      type = if stat.isDirectory() then 'directory' else 'file'
      callback path, type

  init()
