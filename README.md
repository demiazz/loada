# The Loada

The kickass in-browser assets (JS/CSS/Text) loader with the support of localStorage caching and progress tracking. The Loada is here to give you control over assets loading order, parallelism, cache expiration and actual code evaluation. 

Use it to:

  * Make beautiful preloader of the big RICH browser application
  * Manually control assets cache
  * Preload and manage your code partially in the background (templates, extensions, etc...)

## Basic usage

The Loada splits your dependencies into sets. Each set is an instance of The Loada. Each set is atomic in field of caching: if the number of cached assets changes – unused caches get busted on the next run keeping your **localStorage** space usage low. You can i.e. have *main* set, the core of application, and *templates* that will be treated and cached separately.

---

Create a set to start:

```coffee
loader = Loada.set('dependencies') # name of the set defaults to `*` if omitted.
```

To load an asset with the default options run

```coffee
loader.require url: '/assets/application.css'
```

To load several assets one after another (they depend on each other?) run

```coffee
loader.require {url: '/assets/jquery.js'}, {url: '/assets/application.js'}
```

And to load an external library that shouldn't be cached at **localStorage** (but has to be kept at
the browser cache) run

```coffee
loader.require {url: 'http://../facebook.js', localStorage: false}
```

According to our requires, the assets will be loaded in the following groups (:

  * **/assets/application.css** in parallel with
  * (**/assets/jquery.js** and then **/assets/appliation.js**) in parallel with
  * **http://../facebook.js**

And now that we have our dependencies specified, load'em!

```coffee
loader.load
  # During downloading you will get this callback called from time to time
  progress: (percents) -> # ...

  # And this one will run as soon as all assets are around
  complete: -> # ...
```

## Progress tracker limitations and advanced usage

The Loada will try to make progress ticks as often as possible. There are some things you should keep in mind to sort it out though:

  * You can pass in `size` option to the asset options to specify download size. This is the most efficient scenario so if you have a chance to count size programmatically – do that.
  * The Loada will run separate `HEAD` query  for every asset with unknown size expecting server to return `Content-Length`.
  * During downloading it will tick exact percentage for assets with known size and two points at start and finish for every other.

So in the worst case when The Loada was not able to find sizes from any source, you will get percentage split to the number of loading assets. In the best case, when all sizes are known, ticks will happen every 100ms and will be pretty detailed.

**Important note**: The Loada WILL NOT do separate `HEAD` queries unless you pass `progress` callback. So if you don't need the progress tracking feature – you won't get the overhead. In the case when you passed `progress` in and still want to avoid `HEAD` queries (resulting into "per-library" percentage), pass `0` as the `size` value to every asset.

## Options and Methods

### Instance-level options

```coffee
set = Loada.set 'name',
  prefix: 'foobar'
  localStorage: false
```

  * **prefix**: changes localStorage keys prefix (defaults to `loada`)
  * **localStorage**: globally turns off the localStorage cache and (unfortunately) detailed progress tracking

**Important note**: The Loada is only able to work with JS with localStorage mode turned off.

### Asset-level options

```coffee
set.require
  url: '/assets/application.js'
  key: 'app'
  type: 'js'
  revision: 1
  expires: 5
  cache: true
  require: true
  size: 0
```
  * **url**: URL to download asset from
  * **key**: key to use to store asset within the set (defaults to `url`)
  * **type**: type of the asset: `css`, `js` or `text` (The Loada tries to parse URL to get extension if omitted)
  * **revision**: asset revision to control cache expiration manually – cache will get busted if new values doesn't match the stored one
  * **expires**: number of hours to keep asset for (defaults to forever cache)
  * **cache**: pass `false` in to turn localStorage caching off for this particular asset
  * **require**: whether asset should be automatically required or just downloaded and cached
  * **size**: downloadable size of asset to help The Loada with detailed progress tracking

### Instance-level methods

#### **get**

Gets raw asset source by its key

```coffee
source = set.get 'app'
```

#### **expire**

Manually triggers expiration check for current storage

```coffee
set.expire()
```

#### **clear**

Busts all cache of the current set

```coffee
set.clear()
```

## History

Loada is an extraction from [Joosy](http://joosy.ws) core.