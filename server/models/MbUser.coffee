mongoose = require 'mongoose'
plugins = require '../plugins/plugins'
jsonschema = require '../../app/schemas/models/level'
config = require '../../server_config'

#Schema 结构
MbUserSchema = new mongoose.Schema({
  dateCreated:
    type: Date
    'default': Date.now
  email: String
  name: String
  password: String
  mbid:#字段唯一 unique: true,index: true
    type:String
    unique: true
    index: true
}, {strict: true})

#添加 MbUser 实例方法.
MbUserSchema.methods.setMbidNamePassword = (mbid, name,password) ->
  @set('mbid',mbid)
  @set('name',name)
  @set('password',password)

#插入方法处理。 保存密码前，对密码进行处理
MbUserSchema.pre('save', (next) ->
  @set('password2',@get('password')) if @get('password')
  next()
  @set('password',"")
  @set('password2',"")
)

MbUserSchema.post 'init', (doc) ->

module.exports = MbUser = mongoose.model('mbid.test', MbUserSchema)
