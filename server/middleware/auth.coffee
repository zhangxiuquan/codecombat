# Middleware for both authentication and authorization

errors = require '../commons/errors'
wrap = require 'co-express'
Promise = require 'bluebird'
parse = require '../commons/parse'
request = require 'request'
User = require '../models/User'
utils = require '../lib/utils'
mongoose = require 'mongoose'
authentication = require 'passport'
sendwithus = require '../sendwithus'
LevelSession = require '../models/LevelSession'

#获取
MbUser = require '../models/MbUser'

module.exports =
  checkDocumentPermissions: (req, res, next) ->
    console.log("检查是权限")
    return next() if req.user?.isAdmin()
    if not req.doc.hasPermissionsForMethod(req.user, req.method)
      if req.user
        return next new errors.Forbidden('You do not have permissions necessary.')
      return next new errors.Unauthorized('You must be logged in.')
    next()
    
  checkLoggedIn: ->
    return (req, res, next) ->
      console.log("检查是否登陆")
      if (not req.user) or (req.user.isAnonymous())
        return next new errors.Unauthorized('You must be logged in.')
      next()
    
  checkHasPermission: (permissions) ->
    if _.isString(permissions)
      permissions = [permissions]
    
    return (req, res, next) ->
      if not req.user
        return next new errors.Unauthorized('You must be logged in.')
      if not _.size(_.intersection(req.user.get('permissions'), permissions))
        return next new errors.Forbidden('You do not have permissions necessary.')
      next()

  checkHasUser: ->
    console.log("检查是否存在用户checkHasUser")
    return (req, res, next) ->
      if not req.user
        return next new errors.Unauthorized('No user associated with this request.')
      next()

  whoAmI: wrap (req, res) ->
    if not req.user
      user = User.makeNew(req)
      yield user.save()
      req.logInAsync = Promise.promisify(req.logIn)
      yield req.logInAsync(user)
      
    if req.query.callback
      res.jsonp(req.user.toObject({req, publicOnly: true})) 
    else
      res.send(req.user.toObject({req, publicOnly: false}))
    res.end()

  afterLogin: wrap (req, res, next) ->

    console.log("afterLogin");
    activity = req.user.trackActivity 'login', 1
    yield req.user.update {activity: activity}
    res.status(200).send(req.user.toObject({req: req}))


  loginByGPlus: wrap (req, res, next) ->
    gpID = req.body.gplusID
    gpAT = req.body.gplusAccessToken
    throw new errors.UnprocessableEntity('gplusID and gplusAccessToken required.') unless gpID and gpAT

    url = "https://www.googleapis.com/oauth2/v2/userinfo?access_token=#{gpAT}"
    [googleRes, body] = yield request.getAsync(url, {json: true})
    idsMatch = gpID is body.id
    throw new errors.UnprocessableEntity('Invalid G+ Access Token.') unless idsMatch
    user = yield User.findOne({gplusID: gpID})
    throw new errors.NotFound('No user with that G+ ID') unless user
    req.logInAsync = Promise.promisify(req.logIn)
    yield req.logInAsync(user)
    next()

  loginByFacebook: wrap (req, res, next) ->
    fbID = req.body.facebookID
    fbAT = req.body.facebookAccessToken
    throw new errors.UnprocessableEntity('facebookID and facebookAccessToken required.') unless fbID and fbAT

    url = "https://graph.facebook.com/me?access_token=#{fbAT}"
    [facebookRes, body] = yield request.getAsync(url, {json: true})
    idsMatch = fbID is body.id
    throw new errors.UnprocessableEntity('Invalid Facebook Access Token.') unless idsMatch
    user = yield User.findOne({facebookID: fbID})
    throw new errors.NotFound('No user with that Facebook ID') unless user
    req.logInAsync = Promise.promisify(req.logIn)
    yield req.logInAsync(user)
    next()

    #使用id登录
  loginByMbID: wrap (req, res) ->
    console.log("loginByMbID登陆2")
    mbid =  req.query.mbid or req.body.mbid or  req.params.mbid

    if not mbid
      res.send({})
      console.log("没有mbid")
      return

    user = yield MbUser.findOne({mbid:mbid})
    console.log user
    if not user
      res.send({msg:'没找到记录'})
      console.log("没找到记录"+mbid)
      return

    #从数据库中获取mbid对应的acount和password. 先测试,写假的用户名邮箱和密码
    name  = user.get('name')
    email  =  user.get('email')
    password=  user.get('password')

    #1. 自动登录，如果登录不了，则自动注册（密码错误需要另行处理）
    user = yield User.findOne({email:email})
    if  user and user.get('email')
      #找到用户，则登录成功，则继续返回页面
      console.log("自动登录"+name)
      req.logInAsync = Promise.promisify(req.logIn)
      yield req.logInAsync(user)
      res.send({})
      return
    #没有用户，账号不存在。 则自动注册
    console.log("没有用户"+name)
    #2.自动注册
    #如果已经登录，且不是匿名用户，则注销登录
    if (not req.user) and (not req.user.isAnonymous())
      console.log("注销用户"+name)
      req.logout()
    #注册
    console.log("注册"+name)
    user = User.makeNew(req)
    #设置用户数据，然后保存到数据库，即可完成注册
    user.set('email',email)
    user.set('password',password)
    user.set('name',name)
    user.set('preferredLanguage',"zh-HANS")
    user.set('birthday',"1980-01-01T00:00:00.000Z")
    user.set('generalNews',{enabled: true})
    yield user.save()
    console.log "注册成功"
    #登陆设置seesion
    req.logInAsync = Promise.promisify(req.logIn)
    yield req.logInAsync(user)
    res.send(user)

  #添加mbid,对应的账户、邮箱、密码
  addMbID: wrap (req, res) ->
    #获取参数，query是get方法，body是post json的参数。
    console.log "addMbID"
    mbid = req.body.mbid or req.query.mbid
    name = req.body.name or req.query.name
    email = req.body.email or req.query.email
    password = req.body.password or req.query.password
    #校验参数
    console.log mbid+' '+name+' '+email+' '+password
    return res.send({msg:'没有mbid参数',err:1}) if not mbid
    return res.send({msg:'没有name参数',err:2}) if not name
    return res.send({msg:'没有email参数',err:3}) if not email
    return res.send({msg:'没有password参数',err:4}) if not password
    #校验是否已经存在mbid
    user = yield  MbUser.findOne({mbid:mbid})
    return res.send({msg:'存在相同的mbid',err:5}) if user
    #保存
    user= new MbUser({mbid:mbid,name:name,email:email,password:password })
    yield user.save()
    console.log '添加成功'
    console.log user
    res.send({msg:'添加成功',err:0,user:user})


  spy: wrap (req, res) ->
    throw new errors.Unauthorized('You must be logged in to enter espionage mode') unless req.user
    throw new errors.Forbidden('You must be an admin to enter espionage mode') unless req.user.isAdmin()
    
    user = req.body.user
    throw new errors.UnprocessableEntity('Specify an id, username or email to espionage.') unless user
    user = yield User.search(user)
    amActually = req.user
    throw new errors.NotFound() unless user
    req.loginAsync = Promise.promisify(req.login)
    yield req.loginAsync user
    req.session.amActually = amActually.id
    res.status(200).send(user.toObject({req: req}))
    
  stopSpying: wrap (req, res) ->
    throw new errors.Unauthorized('You must be logged in to leave espionage mode') unless req.user
    throw new errors.Forbidden('You must be in espionage mode to leave it') unless req.session.amActually
    
    user = yield User.findById(req.session.amActually)
    delete req.session.amActually
    throw new errors.NotFound() unless user
    req.loginAsync = Promise.promisify(req.login)
    yield req.loginAsync user
    res.status(200).send(user.toObject({req: req}))

  logout: (req, res) ->
    req.logout()
    res.send({})

  reset: wrap (req, res) ->
    unless req.body.email
      throw new errors.UnprocessableEntity('Need an email specified.', {property: 'email'})

    user = yield User.findOne({emailLower: req.body.email.toLowerCase()})
    if not user
      throw new errors.NotFound('not found', {property: 'email'})

    user.set('passwordReset', utils.getCodeCamel())
    yield user.save()
    context =
      email_id: sendwithus.templates.password_reset
      recipient:
        address: req.body.email
      email_data:
        tempPassword: user.get('passwordReset')
    sendwithus.api.sendAsync = Promise.promisify(sendwithus.api.send)
    yield sendwithus.api.sendAsync(context)
    res.end()
    
  unsubscribe: wrap (req, res) ->
    # need to grab email directly from url, in case it has "+" in it
    queryString = req.url.split('?')[1] or ''
    queryParts = queryString.split('&')
    email = null
    for part in queryParts
      [name, value] = part.split('=')
      if name is 'email'
        email = value
        break
    
    unless email
      throw new errors.UnprocessableEntity 'No email provided to unsubscribe.'
    email = decodeURIComponent(email)

    if req.query.session
      # Unsubscribe from just one session's notifications instead.
      session = yield LevelSession.findOne({_id: req.query.session})
      if not session
        throw new errors.NotFound "Level session not found"
      session.set 'unsubscribed', true
      yield session.save()
      res.send "Unsubscribed #{email} from CodeCombat emails for #{session.get('levelName')} #{session.get('team')} ladder updates. Sorry to see you go! <p><a href='/play/ladder/#{session.levelID}#my-matches'>Ladder preferences</a></p>"
      res.end()
      return

    user = yield User.findOne({emailLower: email.toLowerCase()})
    if not user
      throw new errors.NotFound "No user found with email '#{email}'"

    emails = _.clone(user.get('emails')) or {}
    msg = ''

    if req.query.recruitNotes
      emails.recruitNotes ?= {}
      emails.recruitNotes.enabled = false
      msg = "Unsubscribed #{email} from recruiting emails."
    else if req.query.employerNotes
      emails.employerNotes ?= {}
      emails.employerNotes.enabled = false
      msg = "Unsubscribed #{email} from employer emails."
    else
      msg = "Unsubscribed #{email} from all CodeCombat emails. Sorry to see you go!"
      emailSettings.enabled = false for emailSettings in _.values(emails)
      emails.generalNews ?= {}
      emails.generalNews.enabled = false
      emails.anyNotes ?= {}
      emails.anyNotes.enabled = false

    yield user.update {$set: {emails: emails}}
    res.send msg + '<p><a href="/account/settings">Account settings</a></p>'
    res.end()

  name: wrap (req, res) ->
    if not req.params.name
      throw new errors.UnprocessableEntity 'No name provided.'
    originalName = req.params.name
      
    User.unconflictNameAsync = Promise.promisify(User.unconflictName)
    name = yield User.unconflictNameAsync originalName
    response = name: name
    if originalName is name
      res.send 200, response
    else
      throw new errors.Conflict('Name is taken', response)
