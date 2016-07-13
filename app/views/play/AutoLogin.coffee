RootView = require 'views/core/RootView'
template = require 'templates/play/autologin-view'
#template = require 'templates/play/campaign-view'

module.exports = class AutoLoginView extends RootView
  id: 'autologin-view'
  template:template
  #events:
  #  'click #my-btn': 'onClickMButton'

  initialize:(options)->

  onLoaded:->


  afterRender: ->
    super()
    @loginOrRegist()

  afterRender2: ->
    super()
    #获取url中的用户名，密码
    acount= @getQueryStr('acount')
    password =@getQueryStr('password')
    @$('#msg').text(acount+":"+password)
    @callLogin acount,password


  getQueryStr:(key)->
    rs = new RegExp("(^|)" + key + "=([^&]*)(&|$)", "gi").exec(window.document.location.href);
    return rs[2]  if (rs && rs.length>2)
    return ""


  callLogin:(acount,password)->
    #自动登陆，如果登陆成功，跳转游戏页面，如果登陆失败，自动注册
    console.log acount+":"+password
    jqxhr = $.post('/auth/login',
      {username: acount,password: password },
       (model) ->
         console.log "登陆成功自动跳转"
         window.location.href = "/play"
       )
    jqxhr.fail((jqxhr) =>
                  console.log "登陆失败，调用注册"
                  @callRegirst acount,password
              )

  callRegirst:(acount,password)->
    #自动注册，如果注册成功，跳转游戏页面，如果注册失败，也跳转游戏页面（自动匿名）
#自动登陆，如果登陆成功，跳转游戏页面，如果登陆失败，自动注册
    console.log acount+":"+password
    userJson={preferredLanguage:"zh-HANS",birthday:"1980-01-01T00:00:00.000Z",email:acount,generalNews: {enabled: true},name: acount,password: password}
    jqxhr = $.post('/db/user',userJson,
      (model) ->
        console.log "注册成功自动跳转"
        window.location.href = "/play"
    )
    jqxhr.fail((jqxhr) =>
      console.log jqxhr
      console.log "注册失败，也跳转，自动匿名，或则已经有账号登陆了不能注册，使用原账号"
      window.location.href = "/play"
    )

  loginOrRegist:->
    #获取url中的用户名，密码
    jqxhr = $.get('/auth/login-mbid?n=2&mbid='+@getQueryStr('mbid'),
      (model) ->
        window.location.href = "/play"
    )
    jqxhr.fail((jqxhr) =>
        window.location.href = "/play"
    )