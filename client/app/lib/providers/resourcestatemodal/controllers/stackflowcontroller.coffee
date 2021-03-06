kd = require 'kd'
InstructionsController = require './instructionscontroller'
CredentialsController = require './credentialscontroller'
BuildStackController = require './buildstackcontroller'
environmentDataProvider = require 'app/userenvironmentdataprovider'
helpers = require '../helpers'
constants = require '../constants'
showError = require 'app/util/showError'

module.exports = class StackFlowController extends kd.Controller

  constructor: (options, data) ->

    super options, data

    { stack } = @getData()
    @state    = stack.status?.state


  loadData: ->

    { stack } = @getData()
    { computeController } = kd.singletons

    computeController.fetchBaseStackTemplate stack, (err, stackTemplate) =>
      return showError err  if err

      @bindToKloudEvents()
      @setup stackTemplate

      @credentials.loadData()
      @credentials.ready @bound 'show'


  bindToKloudEvents: ->

    { stack } = @getData()

    { computeController } = kd.singletons
    { eventListener }     = computeController

    computeController.on "apply-#{stack._id}", @bound 'updateStatus'
    computeController.on "error-#{stack._id}", @bound 'onKloudError'
    computeController.on [ 'CredentialAdded', 'CredentialRemoved'], =>
      @credentials?.reloadData()

    if @state is 'Building'
      eventListener.addListener 'apply', stack._id


  setup: (stackTemplate) ->

    { stack, machine } = @getData()
    { container }      = @getOptions()

    @instructions = new InstructionsController { container }, stackTemplate
    @credentials  = new CredentialsController { container }, stack
    @buildStack   = new BuildStackController { container }, { stack, stackTemplate, machine }

    @instructions.on 'NextPageRequested', => @credentials.show()
    @credentials.on 'InstructionsRequested', => @instructions.show()
    @credentials.on 'StartBuild', @bound 'startBuild'
    @buildStack.on 'CredentialsRequested', => @credentials.show()

    @buildStack.on 'RebuildRequested', (stack) =>
      stack.status.state = 'NotInitialized'
      @credentials.setData stack
      @credentials.submit()

    @forwardEvent @buildStack, 'ClosingRequested'


  updateStatus: (event, task) ->

    { status, percentage, message, error } = event

    { machine, stack } = @getData()
    machineId = machine.jMachine._id

    return  unless helpers.isTargetEvent event, stack

    [ prevState, @state ] = [ @state, status ]

    if error
      @buildStack.showError error
    else if percentage?
      @buildStack.updateBuildProgress percentage, message
      return unless percentage is constants.COMPLETE_PROGRESS_VALUE

      if prevState is 'Building' and @state is 'Running'
        { computeController } = kd.singletons
        computeController.once "revive-#{machineId}", =>
          @buildStack.completeBuildProcess()
          @checkIfResourceRunning 'BuildCompleted'
    else
      @checkIfResourceRunning()


  checkIfResourceRunning: (reason) ->

    @emit 'ResourceBecameRunning', reason  if @state is 'Running'


  startBuild: (identifiers) ->

    { stack } = @getData()

    if stack.config?.oldOwner?
      return @updateStatus
        status  : @state
        error   : 'Stack building is not allowed for disabled users\' stacks.'
        eventId : stack._id

    kd.singletons.computeController.buildStack stack, identifiers

    @updateStatus
      status     : 'Building'
      percentage : constants.INITIAL_PROGRESS_VALUE
      eventId    : stack._id


  onKloudError: (response) ->

    message = response.err?.message ? response.message
    @buildStack.showError message


  show: ->

    controller = switch @state
      when 'Building' then @buildStack
      when 'NotInitialized' then @instructions

    controller.show()  if controller


  destroy: ->

    { stack } = @getData()

    { computeController } = kd.singletons
    computeController.off "apply-#{stack._id}", @bound 'updateStatus'
    computeController.off "error-#{stack._id}", @bound 'onKloudError'

    super
