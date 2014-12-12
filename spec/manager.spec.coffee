###
  Спеки запросов работы с типстерами
###

WorkerQueue = require '../lib/worker_queue'

log = console.log.bind console

xdescribe 'spec manager workers', ->
  worker1 = null

  before (done) ->
    worker1 = new WorkerQueue 'test.worker'
    done()

  after (done) ->
    worker1.close()
    done()

  describe 'with workers', ->
    it 'send message and get responce', (done) ->
      message = null
      mess = foo: 123
      worker1.onStart ->
        worker1.send mess
        worker1.onMessage (message) ->
          message.foo.should.equal mess.foo
          # Ждём успешного завершения работы
          worker1.onSuccess ->
            done()

    it 'recovery worker', (done) ->
      worker1.send 'killyourself' # Типа чтобы сам себя прибил
      await worker1.getWorker().on 'close', defer()
      done()

    it 'throw error for worker', (done) ->
      worker1.onError ->
        done()
      worker1.send 'throw_error'

    it 'check exist worker', ->
      WorkerQueue.existWorker('test.worker').should.be.true