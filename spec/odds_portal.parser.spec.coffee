# spec.coffee
fs = require 'fs'
oddsportal_matches = require '../lib/oddsportal_matches'

##
# вытаскиваем файл с коэфицентами
odds_mocks = (fs.readFileSync "#{__dirname}/../mock.js").toString()


describe 'spec parser functions to OddsPortal.com', ->

  it 'check date by class string', ->
    oddsportal_matches.$checkDateMatchByClass('table-time datet t1387828800-8-1-0-0 ')
      .should.eql new Date 1387828800 * 1000


  describe 'class Match', ->
    Match = oddsportal_matches.Match

    describe 'constants', ->
      it 'handicap', ->
        Match.handicap.should.be.equal 'handicap'

    it 'create object', ->
      $date = new Date 'Tue Nov 26 2013  GMT+0400 (MSK)'
      $match = new Match 
        event: 'Arsenal - Marseille'
        date: $date
        score: '1 - 1'
        bet: '+2.5'
        type: Match.handicap

      $match.should.be.defined
      $match.event.should.be.defined
      $match.date.should.be.equal $date

    it 'date validate', ->
      $date = new Date 'Tue Nov 26 2013  GMT+0400 (MSK)'
      $match = new Match
        event: 'Arsenal - Marseille'
        date: $date

      $match2 = new Match date: new Date 'Tue Nov 26 2013 23:00:00 GMT+0400 (MSK)'

      $match.validateDateEvent($match2).should.be.true
      $match.validateDateEvent(new Date).should.be.false # !

    it 'should set #id match if check ', ->
      $match = new Match link_result: 'http://www.oddsportal.com/soccer/europe/' +
                                      'champions-league-2013-2014/arsenal-marseille-dCDtCNDM/'
      $match._id.should.equal 'dCDtCNDM'

    it 'parse odds from source', ->
      $match = new Match
        betOnTeam: Match.home
        bet: '-2.5'
        type: Match.handicap
      $match.parseOdds odds_mocks

      $match.odds.should.be.equal 4.65
      $match.bookmaker.should.be.equal 'Bet365'

    it 'parse odds from source #2', ->
      $match = new Match
        betOnTeam: Match.away
        bet: '+1'
        type: Match.handicap
      $match.parseOdds odds_mocks
      $match.odds.should.be.equal 1.85