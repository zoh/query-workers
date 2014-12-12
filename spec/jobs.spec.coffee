###
  Спека описывающая работу по созданию и управлению
  задач в очередь
###

log = console.log.bind console
cfg = require '../../config'
manageJobs = require '../lib/jobs'
_ = require('underscore')

kue = require 'kue'
redis = require 'redis'
kue.redis.createClient = ->
  client = redis.createClient()
  client.auth cfg.redis.password
  client
kue_jobs = kue.createQueue()


job =
  title: 'jackpot last tips'
  tipster: 'jackpot xm'
  date_add: Date.now()

job2 =
  title: 'aggree stats'
  tipster: 'jackpot'
  date_add: Date.now()

converJob = (_job) ->
  _job = _.clone(_job)
  _job.title =  "#{JOB_PARSE_NEW}: " + _job.title
  _job


describe 'spec to interface create jobs', ->
  before (done) ->
    manageJobs.deleteAllJobs JOB_PARSE_NEW, done
#
  afterEach (done) ->
    manageJobs.deleteAllJobs JOB_PARSE_NEW, done

  it 'get jobs', (done) ->
    await manageJobs.createJob JOB_PARSE_NEW, job, defer()
    await manageJobs.createJob JOB_STATIC_AGGR, job2, defer()
#    await setTimeout defer(), 3000
    manageJobs.search JOB_PARSE_NEW, (err, tips) ->
      tips.length.should.equal 1
      tips[0].data.should.eql converJob(job)
      done()

  describe ' doubles jobs', ->
    it 'check double job', (done) ->
      await manageJobs.createJob JOB_PARSE_NEW, job, defer()
      await manageJobs.search JOB_PARSE_NEW, defer err, jobs
      jobs[0].data.should.eql converJob(job)
      _id = jobs[0].id

      await manageJobs.createJob JOB_PARSE_NEW, job, defer err
      err.message.should.equal 'Обнаружена существующая задача'
      await setTimeout defer(), 10

      manageJobs.search job.title, (err, tips) ->
        tips.length.should.equal 1
        tips[0].id.should.equal _id
        done()

  describe 'delayed job', ->
    it 'create', (done) ->
      await manageJobs.createJobDelay JOB_PARSE_NEW+1, job, 500, defer()
      kue_jobs.promote(100)
      await kue_jobs.process JOB_PARSE_NEW+1, 1, defer(_job, $done)
      _job._state.should.equal 'active'
      $done()
      await manageJobs.getJobById _job.id, defer err, _job2
      _job2._state.should.equal 'complete'
      done()

  describe 'specific jobs create', ->
    tipster_nameshort = 'jackpot'
    last_tips =
      date_event: '10.11.2012'
      event: 'Бавария Манчестер'
      odds: '2.11'
    _job = null
    global.DELAY_JOB_AGGR = 100

    it 'parse all tips for tipster', (done) ->
      await manageJobs.addJobParseAllTips tipster_nameshort, defer _job
      await kue_jobs.process JOB_PARSE_ALL, 1, defer(_job, $done)
      _job.data.tipster.should.equal tipster_nameshort
      _job.data.title.should.be.ok
      done()

    it 'add job with undefined tipster', (done) ->
      await manageJobs.addJobParseAllTips undefined, defer _job
      _job.should.be.instanceof Error
      _job.message.should.equal 'Не передан парамметр short_name типстера'
      done()

    it 'parse new tips for tipster', (done) ->
      await manageJobs.addJobParseNewTips tipster_nameshort, last_tips, defer _job
      await kue_jobs.process JOB_PARSE_NEW, 1, defer(_job, $done)
      done()

    it 'statistics aggregate for tipster', (done) ->
      await manageJobs.addJobAggregate tipster_nameshort, defer _job
      await kue_jobs.process JOB_STATIC_AGGR, 1, defer(_job, $done)
      _job.data.tipster.should.equal tipster_nameshort
      _job.data.title.should.be.ok
      done()