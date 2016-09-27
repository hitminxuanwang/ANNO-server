require! {
    \prelude : _

    \express
    \mongoose
    \async
    \../config
    \../app/models
}

app = express!

my-object = models.Object

mongoose.connect config.database
mongoose.connection.on \error ->
    console.log 'Error: Could not connect to MongoDB. Did you forget to run `mongod`?'

app.get \/test, (req, res) ->
    res.send \ok!

app.use \/list-objects, (req, res, next) ->
    page = parseInt req.body.page
    if page == NaN then page = 1
    my-object.find req.body.{parent}, (err, objs) ->
        if err then return next err
        res.send objs
    .sort [['_id', -1]]
    .skip (page - 1) * config.page-size
    .limit config.page-size

app.use \/find-objects, (req, res, next) ->
    my-object.find req.body, (err, objs) ->
        if err then return next err
        res.send objs

app.use \/find-one, (req, res, next) ->
    if req.body.parent == ''
        req.body.parent = undefined
    my-object.find-one req.body, (err, obj) ->
        if err then return next err
        res.send obj

find-neighbour = (is-next, req, res, next) ->
    func = (err, docs) ->
        if err then return next err
        if docs[0]?
            res.send docs[0]{_id}
        else
            res.send {}
    if is-next == \1
        qobj = {'_id':{'$lt':req.body._id}}
    else
        qobj = {'_id':{'$gt':req.body._id}}
    if req.body.parent?
        qobj.parent = req.body.parent
    if req.body.state?
        qobj.state = req.body.state
    console.log qobj, req.body
    my-object.find qobj, func
        .sort [['_id', if is-next==\1 then -1 else 1]]
        .limit 1

app.use \/find-neighbour, (req, res, next) ->
    find-neighbour req.body.is-next, req, res, next

app.post \/new-object, (req, res, next) ->
    # just test
    if req.body.url == '404'
        res.status 404 .send "failed."
        return
    if req.body.url == 'wait'
        do
            <- set-timeout _, 5000
            res.send "timeout ok!"
        return

    if req.body._id?
        edit-obj = {} <<< req.body
        id = delete edit-obj._id
        my-object.update {_id:id}, {$set:edit-obj}, ->
            if it then return next it
            res.send "Edit id:#{id} successfully!"
    else
        object = new my-object req.body
        object.save ->
            if it then return next it
            res.send "#{req.body.name} saved successfully."

app.post \/delete-items, (req, res, next) ->
    console.log req.body['items[]']
    items = req.body['items[]']
    if items
        items = [items] if not Array.isArray items
    else
        return res.send "No item was deleted."

    my-object.remove {_id:{$in:items}}, ->
        if it then return next it
        res.send "Delete #{items.length} items successfully!"

app.post \/save-mark, (req, res, next) ->
    console.log req.body
    res.send \ok.

app.post \/counter, (req, res, next) ->
    my-counter = (cond, cb) ->
        cond <<< req.body.{parent}
        my-object.count cond, cb

    async.parallel {
        \total : (callback) ->
            my-counter {}, callback
        \annotated : (callback) ->
            my-counter {state:'annotated'}, callback
        \un-annotated : (callback) ->
            my-counter {state:'un-annotated'}, callback
        \issued : (callback) ->
            my-counter {state:'issued'}, callback
    }, (err, results) ->
        if err then return next err
        results.page-size = config.page-size
        res.send results
app.use (req, res) ->
    res.status 404 .send "api #{req.url} not found."

console.log "hello from api."

module.exports = app
