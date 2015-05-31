Tasks = new Mongo.Collection("tasks")

if Meteor.isClient
  # This code only runs on the client
  Meteor.subscribe("tasks")

  Template.body.helpers
    tasks: ->
      if Session.get("hideCompleted")
        # If hide completed is checked, filter tasks
        Tasks.find({checked: {$ne: true}}, {sort: {createdAt: -1}})
      else
        # Otherwise, return all of the tasks
        Tasks.find({}, {sort: {createdAt: -1}})

    hideCompleted: ->
      Session.get("hideCompleted")

    incompleteCount: ->
      Tasks.find({checked: {$ne: true}}).count()

  Template.task.helpers
    isOwner: ->
      this.owner is Meteor.userId()

  Template.body.events
    "submit .new-task": (event) ->
      # This function is called when the new tasks form is submitted
      text = event.target.text.value

      Meteor.call("addTask", text)

      # Clear form
      event.target.text.value = ""

      # Prevent default form submit
      false

    "click .toggle-checked": ->
      # Set the checked property to the opposite of its current value
      Meteor.call("setChecked", this._id, !this.checked)

    "click .toggle-private": ->
      Meteor.call("setPrivate", this._id, !this.private)

    "click .delete": ->
      Meteor.call("deleteTask", this._id)

    "change .hide-completed input": (event) ->
      Session.set("hideCompleted", event.target.checked)

  Accounts.ui.config
    passwordSignupFields: "USERNAME_ONLY"

Meteor.methods
  addTask: (text) ->
    # Make sure the user is logged in before inserting a task
    if !Meteor.userId()
      throw new Meteor.Error("not-authorized")

    Tasks.insert
      text: text
      createdAt: new Date()             # current time
      owner: Meteor.userId()            # _id of logged in user
      username: Meteor.user().username  # username of logged in user

  deleteTask: (taskId) ->
    task = Tasks.findOne(taskId)
    if task.private and task.owner isnt Meteor.userId()
      # If the task is private, make sure only the owner can delete it
      throw new Meteor.Error("not-authorized")

    Tasks.remove(taskId)

  setChecked: (taskId, setChecked) ->
    task = Tasks.findOne(taskId)
    if task.private and task.owner isnt Meteor.userId()
      # If the task is private, make sure only the owner can check it off
      throw new Meteor.Error("not-authorized")

    Tasks.update(taskId, {$set: {checked: setChecked}})

  setPrivate: (taskId, setToPrivate) ->
    task = Tasks.findOne(taskId)

    # Make sure only the task owner can make a task private
    if task.owner isnt Meteor.userId()
      throw new Meteor.Error("not-authorized")

    Tasks.update(taskId, {$set: {private: setToPrivate}})

if Meteor.isServer
  Meteor.publish "tasks", ->
    Tasks.find
      $or: [
        {private: {$ne: true}}
        {owner: this.userId}
      ]
