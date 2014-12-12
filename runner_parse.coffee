###
  Запускает задачи для типстеров
  Передать их можно или через парамметры или по умолчанию возьмёт из папки workers
###

jobsManager = require './lib/jobs'
argv = require('optimist').argv
Sync = require 'sync'
fs = require 'fs'


getTipsterForJobs = ->
  workers = fs.readdirSync __dirname + '/workers'
  tipsters = []
  for worker in workers
    if res = worker.match 'parse_tipster\.(.*)\.(new|all)'
      tipsters.push name: res[1], type: res[2]
  tipsters

getParseArgv = (tipsters) ->
  tipsters?.map (item) ->
    item = item.split ':'
    name: item[0]
    type: item[1]

createJobsFor = (tipsters) ->
  __count = tipsters?.length
  for tipster in tipsters
    if tipster.type is 'all'
      jobsManager.addJobParseAllTips tipster.name
    else if tipster.type is 'new'
      jobsManager.addJobParseNewTips tipster.name, {first_runner: true}, (err) ->
        console.log err if err
        --__count || process.exit()
      , NONE_DELAY_JOB_AGGR
      # Тут мы передаём минимальную задержку


switch true
  when argv.t?
    # coffee *  -t tipster1:new  -t tipster1:all  -t tipster2:new
    createJobsFor getParseArgv argv.t
  when argv.all?
    # coffee * --all
    createJobsFor getTipsterForJobs()
  else
    console.log 'Список типсетров:'
    console.log " * #{item.name}:#{item.type}" for item in getTipsterForJobs()
    process.exit()