###
  Запуск JSON API Kue
###

kue = require 'kue'
cfg = require '../config'
redis = require 'redis'

kue.redis.createClient = ->
  client = redis.createClient()
  client.auth cfg.redis.password
  client

jobs = kue.createQueue()
express = require 'express'
jobs.promote 1000

allowCrossDomain = (req, res, next) ->
  res.header 'Access-Control-Allow-Origin', '*'
  res.header 'Access-Control-Allow-Methods', 'GET,PUT,POST,DELETE,OPTIONS'
  res.header 'Access-Control-Allow-Headers', 'Content-Type, Authorization, Content-Length, X-Requested-With'
  # intercept OPTIONS method
  if 'OPTIONS' is req.method
    res.send 200
  else
    next()

app = express()
app.use allowCrossDomain
app.use express.basicAuth cfg.kue.login, cfg.kue.password
app.use kue.app
app.listen cfg.kue.port

console.log 'UI started on port ' + cfg.kue.port