describe "Loada", ->

  beforeEach ->
    Loada.debug = false
    window.sandbox = {}

  afterEach ->
    delete window.sandbox

  it "initializes properly", ->
    set = Loada.set(undefined, localStorage: false)
    expect(set.set).toEqual '*'
    expect(set.options.localStorage).toBeFalsy()
    expect(set.storage).toEqual {}

    localStorage['loada.foo'] = JSON.stringify('foo': 'bar')

    set = Loada.set 'foo'
    expect(set.set).toEqual 'foo'
    expect(set.options.localStorage).toBeTruthy()
    expect(set.storage).toEqual {'foo': 'bar'}

  describe "expiration", ->
    it "cuts by date", ->
      expired   = new Date
      unexpired = new Date
      unexpired.setTime(unexpired.getTime() + 60*1000)

      libraries = 
        'foo.js': {expirationDate: expired}
        'bar.js': {expirationDate: unexpired}
      localStorage['loada.*'] = JSON.stringify libraries

      set = Loada.set()
      set.require url: 'foo.js'
      set.require url: 'bar.js'

      expect(set.storage['foo.js']).toBeDefined()
      expect(set.storage['bar.js']).toBeDefined()

      set.expire()
      expect(set.storage['foo.js']).toBeUndefined()
      expect(set.storage['bar.js']).toBeDefined()

    it "cuts by existance", ->
      localStorage['loada.*'] = JSON.stringify { 'foo.js': {}, 'bar.js': {} }

      set = Loada.set()
      set.require url: 'bar.js'

      expect(set.storage['foo.js']).toBeDefined()
      expect(set.storage['bar.js']).toBeDefined()

      set.expire()
      expect(set.storage['foo.js']).toBeUndefined()
      expect(set.storage['bar.js']).toBeDefined()

    it "cuts by revision", ->
      localStorage['loada.*'] = JSON.stringify 
        'foo.js': {revision: 1}
        'bar.js': {}
        'baz.js': {}

      set = Loada.set()
      set.require url: 'foo.js', revision: 1
      set.require url: 'bar.js', revision: 1
      set.require url: 'baz.js'

      expect(set.storage['foo.js']).toBeDefined()
      expect(set.storage['bar.js']).toBeDefined()
      expect(set.storage['baz.js']).toBeDefined()

      set.expire()
      expect(set.storage['foo.js']).toBeDefined()
      expect(set.storage['bar.js']).toBeUndefined()
      expect(set.storage['baz.js']).toBeDefined()

  describe "size ensurer", ->
    beforeEach ->
      @set = Loada.set()
      @set.require url: 'foo.js', size: 100
      @set.require url: 'bar.js'
      @set.require url: 'baz.js'
      @server = sinon.fakeServer.create()

    afterEach ->
      @server.restore()

    it "zerofills with no progress tracking", ->
      callback = sinon.spy()
      @set._ensureSizes false, callback
      expect(callback.callCount).toEqual 1
      expect(@set.requires.set['foo.js'].size).toEqual 0

    it "gets sizes with progress tracking", ->
      callback = sinon.spy()
      @set._ensureSizes true, callback

      waits 0

      runs ->
        expect(@server.requests[0].url).toEqual 'bar.js'
        expect(@server.requests[1].url).toEqual 'baz.js'

        @server.requests[0].respond 200, {'Content-Length': '100'}, ''
        @server.requests[1].respond 200, {}, ''

      waits 0

      runs ->
        expect(callback.callCount).toEqual 1
        expect(@set.requires.set['foo.js'].size).toEqual 100
        expect(@set.requires.set['bar.js'].size).toEqual 100
        expect(@set.requires.set['baz.js'].size).toEqual(0)

  describe "loader", ->
    beforeEach ->
      @server = sinon.fakeServer.create()
      @set = Loada.set()
      sinon.stub @set, '_inject'

    afterEach ->
      @server.restore()

    it "gets single from cache", ->
      localStorage['loada.*'] = JSON.stringify 
        'foo.js': {require: true}

      @set.setup()
      callback = sinon.spy()
      @set.require url: 'foo.js'

      @set._loadGroup @set.requires.input[0], null, callback

      waits 0

      runs ->
        expect(@server.requests.length).toEqual 0
        expect(callback.callCount).toEqual 1
        expect(@set._inject.callCount).toEqual 1
        expect(@set._inject.args[0][0]).toEqual [{require: true}]

    it "gets single from net", ->
      callback = sinon.spy()
      @set.require url: 'foo.js'

      @set._loadGroup @set.requires.input[0], null, callback

      waits 0

      runs ->
        @server.requests[0].respond 200, {}, 'foobar'

      waits 0

      runs ->
        library =
          url: 'foo.js'
          key: 'foo.js'
          type: 'js'
          source: 'foobar'
          cache: true
          require: true

        expect(@server.requests.length).toEqual 1
        expect(@set.storage['foo.js']).toEqual library
        expect(callback.callCount).toEqual 1
        expect(@set._inject.callCount).toEqual 1
        expect(@set._inject.args[0][0]).toEqual [library]

    it "orders properly", ->
      @set.require(
        { url: 'foo.js' },
        { url: 'bar.js' }
      )
      @set.require url: 'baz.js'
      @set._inject.restore()

      @set._loadGroup @set.requires.input[0], null, firstGroup = sinon.spy()
      @set._loadGroup @set.requires.input[1], null, secondGroup = sinon.spy()

      waits 0

      runs ->
        @server.requests[0].respond 200, {}, 'window.sandbox.TEST1 = 1'
        @server.requests[2].respond 200, {}, 'window.sandbox.TEST2 = 1'

      waits 0

      runs ->
        expect(firstGroup.callCount).toEqual 0
        expect(secondGroup.callCount).toEqual 1
        expect(window.sandbox.TEST1).toBeUndefined()
        expect(window.sandbox.TEST2).toEqual 1
        @server.requests[1].respond 200, {}, 'window.sandbox.TEST1 = 2'

      waits 0

      runs ->
        expect(firstGroup.callCount).toEqual 1
        expect(secondGroup.callCount).toEqual 1
        expect(window.sandbox.TEST1).toEqual 2

    describe "progress", ->
      it "tracks with cache", ->
        progress = {set: sinon.spy()}

        localStorage['loada.*'] = JSON.stringify 
          'foo.js': {}
          'bar.js': {}

        @set.setup()
        @set.require(
          { url: 'foo.js' },
          { url: 'bar.js' }
        )

        @set._loadGroup @set.requires.input[0], progress, ->

        expect(progress.set.callCount).toEqual 2
        expect(progress.set.args[0]).toEqual ['foo.js', 100]
        expect(progress.set.args[1]).toEqual ['bar.js', 100]

      it "tracks with net", ->
        progress = {set: sinon.spy()}

        @set.require(
          { url: 'foo.js' },
          { url: 'bar.js' }
        )

        @set._loadGroup @set.requires.input[0], progress, ->

        waits 0

        runs ->
          @server.requests[0].respond 200, {}, 'foobar'
          @server.requests[1].respond 200, {}, 'foobar'

        waits 0

        runs ->
          expect(progress.set.callCount).toEqual 2
          expect(progress.set.args[0]).toEqual ['foo.js', 100]
          expect(progress.set.args[1]).toEqual ['bar.js', 100]

  it "inlines", ->
    set = Loada.set()
    callback = sinon.spy()

    set._loadInline {url: 'spec/support/test1_1.js', key: 'test.js', type: 'js'}, null, callback

    waits 100

    runs ->
      expect(callback.callCount).toEqual 1
      expect(window.sandbox.TEST).toEqual 1

  it "injects", ->
    set = Loada.set()
    set._inject source: 'window.sandbox.TEST = 1', type: 'js', require: true

    expect(window.sandbox.TEST).toEqual 1

  it "caches", ->
    set = Loada.set()
    server = sinon.fakeServer.create()
    sinon.stub set, '_inject'
    set.require url: 'foo.js'
    set.require url: 'bar.js'

    set.load()

    waits 0

    runs ->
      expect(server.requests.length).toEqual 2
      server.requests[0].respond 200, {}, 'foobar'
      server.requests[1].respond 200, {}, 'foobar'

    waits 0

    runs ->
      set.load()

    runs ->
      expect(server.requests.length).toEqual 2

    runs ->
      server.restore()
      set._inject.restore()

  it "loads", ->
    progress = sinon.spy()
    success = sinon.spy()

    set = Loada.set()
    set.require url: 'spec/support/test1_1.js'
    set.load
      progress: progress
      success: success

    waits 100

    runs ->
      expect(progress.callCount).toEqual 1
      expect(progress.args[0][0]).toEqual 100
      expect(success.callCount).toEqual 1
      expect(window.sandbox.TEST).toEqual 1

  it "loads text", ->
    set = Loada.set()
    set.require url: 'spec/support/text', key: 'foo', type: 'text'
    set.load()

    waits 100

    runs ->
      expect(set.get 'foo').toEqual 'foobar'

  describe "collisions", ->

    it "loads in correct order with localStorage", ->
      progress = sinon.spy()
      success = sinon.spy()

      set = Loada.set()
      set.require {url: 'spec/support/test1_1.js'}, {url: 'spec/support/test1_2.js'}
      set.load
        progress: progress
        success: success

      waits 100

      runs ->
        expect(progress.callCount).toEqual 2
        expect(progress.args[0][0]).toEqual 50
        expect(progress.args[1][0]).toEqual 100
        expect(success.callCount).toEqual 1
        expect(window.sandbox.TEST).toEqual 2

    it "loads in correct order with inlining", ->
      progress = sinon.spy()
      success = sinon.spy()

      set = Loada.set('*', localStorage: false)
      set.require {url: 'spec/support/test1_1.js'}, {url: 'spec/support/test1_2.js'}
      set.load
        progress: progress
        success: success

      waits 100

      runs ->
        expect(progress.callCount).toEqual 2
        expect(progress.args[0][0]).toEqual 50
        expect(progress.args[1][0]).toEqual 100
        expect(success.callCount).toEqual 1
        expect(window.sandbox.TEST).toEqual 2

    it "loads in correct order when mixed", ->
      progress = sinon.spy()
      success = sinon.spy()

      set = Loada.set('*')
      set.require {url: 'spec/support/test1_1.js'}, {url: 'spec/support/test1_2.js', cache: false}
      set.load
        progress: progress
        success: success

      waits 100

      runs ->
        expect(progress.callCount).toEqual 2
        expect(progress.args[0][0]).toEqual 50
        expect(progress.args[1][0]).toEqual 100
        expect(success.callCount).toEqual 1
        expect(window.sandbox.TEST).toEqual 2