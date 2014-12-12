# spec.coffee

funcs = require '../lib/funcs'

describe 'spec to functionals', ->

  describe 'compare teams', ->
    it 'with substring', ->
      # team2 вложена в team1
      team1 = 'Manchester Un.'
      team2 = 'Manchester'
      funcs.compare(team1, team2).should.be.true

      # а тут ничего
      team1 = 'Manchester Un.'
      team2 = 'FC Manchester'
      funcs.compare(team1, team2).should.be.false

    it 'with diff', ->
      funcs.compareDiff("Manchester Un", "FC Manchester").should.be.true
      funcs.compareDiff("Mancity Un", "FC Manchester").should.be.false
      funcs.compareDiff("Bala (Wal)", "Bala").should.be.true
      funcs.compareDiff("AbraHabraTeam", "abrahabra team").should.be.true
      funcs.compareDiff("d23x23ex23", "ff7t23x76t2").should.be.false

      funcs.compareDiff('Columbus Crew', 'Ufa').should.be.false
      funcs.compareDiff('Portland Timbers', 'Alania').should.be.false


  it 'clear handicap', ->
    funcs.handicap(-> "handicap": '-1.5/2').handicap.should.equal '-1.5, -2'
    funcs.handicap(-> "handicap": '-1.5/2').handicap.should.equal '-1.5, -2'
    funcs.handicap(-> "handicap": '-0/0.5').handicap.should.equal '0, -0.5'
    funcs.handicap(-> "handicap": '+0/0.5').handicap.should.equal '0, +0.5'
    funcs.handicap(-> "handicap": '-0.5/1').handicap.should.equal '-0.5, -1'
    funcs.handicap(-> "handicap": '+0.5/1').handicap.should.equal '+0.5, +1'
    funcs.handicap(-> "handicap": '0').handicap.should.equal('0')

  it 'clear handicap to sum', ->
    funcs.handicapToSum('-1.5, -2').should.equal '-1.75'
    funcs.handicapToSum('-0.5, -1').should.equal '-0.75'
    funcs.handicapToSum('-0.5').should.equal '-0.5'
    funcs.handicapToSum('+0, +0.5').should.equal '0.25'
    funcs.handicapToSum('0, +0.5').should.equal '0.25'
    funcs.handicapToSum('0, -0.5').should.equal '-0.25'


  it 'calculate sum handicap', ->
    funcs.handicapSum('-0.25').should.equal '0, -0.5'
    funcs.handicapSum('+0.25').should.equal '0, +0.5'
    funcs.handicapSum('-0.75').should.equal '-0.5, -1'
    funcs.handicapSum('-1.25').should.equal '-1, -1.5'
    funcs.handicapSum('+1').should.equal '+1'
    funcs.handicapSum('+1.5').should.equal '+1.5'
    funcs.handicapSum('-1.5').should.equal '-1.5'
    funcs.handicapSum('+0').should.equal '0'
    funcs.handicapSum('+1.75').should.equal '+1.5, +2'
    funcs.handicapSum('+1.25').should.equal '+1, +1.5'

  it 'trim, clear space', ->
    # Смотрим как чистим пробелы
    funcs.trim(-> test: ' 1 ', test2: 'sdf ').should.eql test:'1', test2:'sdf'
    funcs.trim(-> test: ' 1 1 ').should.eql test:'1 1'
    funcs.trim(-> test: '    ').should.eql test: ''

  # Посмотрим как ищется
  it 'find teams from string', ->
    funcs.findTeam(->match: 'Mu vs Chelse').should.eql 
      match: 'Mu vs Chelse'
      team_home: 'Mu '
      team_away: ' Chelse'

  it 'select on team ', ->
    match =
      handicap: -0.5
      team_home: '<b>Mu</b>' 
      team_away: 'Chelse'
    funcs.selectOnTeam(->match).should.eql 
      handicap: -0.5
      team_home: '<b>Mu</b>' 
      team_away: 'Chelse'
      betOn: match.team_home
      betOnWithHandicap: match.team_home + " " + match.handicap    
    # Немного
    match =
      handicap: -0.5
      team_home: 'Mu' 
      team_away: '<b>Chelse'
    funcs.selectOnTeam(->match).should.eql 
      handicap: -0.5
      team_home: match.team_home
      team_away: match.team_away
      betOn: match.team_away
      betOnWithHandicap: match.team_away + " " + match.handicap

  it 'clearHtmlTag from object', ->
    funcs.clearHtmlTag(['b', 's'])(->test: "<b>1</b><s>2</s>sdfsdf")
      .should.eql test: '12sdfsdf'

    funcs.clearHtmlTag(['br'])(->test: "test<br />")
      .should.eql test: 'test'

  it 'reverseHandicap', ->
    funcs.reverseHandicap('-1.5, -2').should.equal  '+1.5, +2'
    funcs.reverseHandicap('-1.75').should.equal  '+1.75'
    funcs.reverseHandicap('+1.5, +2').should.equal  '-1.5, -2'
    funcs.reverseHandicap('-0.5, -1').should.equal  '+0.5, +1'    
    funcs.reverseHandicap('0, -0.5').should.equal   '0, +0.5'    
    funcs.reverseHandicap('0').should.equal '0'
    funcs.reverseHandicap('+1').should.equal '-1'


  it 'validate result for match', ->
    match =
      handicap: '+1, +1.5'
      score: '0-0'
      result: 'win'
      team_home: 'Hull City',
      team_away: 'Bristol City',
      betOn: 'Bristol City',
    funcs.validateResult(match).should.be.true
    match =
      result: 'draw'
      handicap: '-1'
      score: '0-0'
      team_home: 'Hull City',
      team_away: 'Bristol City',
      betOn: 'Bristol City',
    funcs.validateResult(match).should.be.false
    match =
      result: 'lose'
      handicap: '-1, -1.5'
      score: '0-0'
      team_home: 'Hull City',
      team_away: 'Bristol City',
      betOn: 'Bristol City',
    funcs.validateResult(match).should.be.true
    match =
      result: 'win'
      handicap: '-1, -1.5'
      score: '2 - 0'
      team_home: 'Hull City',
      team_away: 'Bristol City',
      betOn: 'Hull City',
    funcs.validateResult(match).should.be.true
    match =
      result: 'lose'
      handicap: '-1, -1.5'
      score: '1 - 0'
      team_home: 'Hull City',
      team_away: 'Bristol City',
      betOn: 'Hull City',
    funcs.validateResult(match).should.be.true

    match =
      date: '27/04/13',
      match: 'Hoffenheim vs Nurnberg',
      handicap: '-0.5',
      score: '2-1',
      result: 'win',
      team_home: 'Hoffenheim',
      team_away: 'Nurnberg',
      betOnWithHandicap: 'Hoffenheim  -0.5',
      betOn: 'Hoffenheim',
      compare: true,
      match_id: 'WjDCiGBr',
      link_match: 'http://www.livescore.in/match/WjDCiGBr/#odds-comparison;asian-handicap;full-time',
    funcs.validateResult(match).should.be.true

  xit 'get last tips for tipster', (done) ->
    funcs.getLastMathTipster 'jackpot', (err, last_tips) ->
      console.log 'Какая то ошибка' if err
      console.log  last_tips
      done()