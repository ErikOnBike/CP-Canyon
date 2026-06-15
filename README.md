# Canyon

Canyon is the name of a framework for developing standalone mobile apps using
[CodeParadise](https://github.com/ErikOnBike/CodeParadise) based on
[Ionic](https://ionicframework.com).

Loading Canyon can be done using:

```Smalltalk
Metacello new
  repository: 'github://ErikOnBike/CP-Canyon';
  baseline: 'CpCanyon';
  load.
```

Documentation specific to Canyon is fully absent.

A typical Canyon app will have a Smalltalk image of about 600Kb to 800Kb (which will
run in the browser together with a 270Kb Smalltalk VM). If the standalone requirement
is not hard, a typical REST server image (also developed in Smalltalk) will be about
450Kb to 550Kb in size. It will run on a 280Kb Smalltalk VM in NodeJS (or compatible).


### Usage warning

Canyon was started as a tool to help develop two mobile apps. The mobile apps were both
intended to be run 'standalone', requiring all code to be in the browser (instead of
relying on a server being present). This deviates quite considerable from CodeParadise's
main approach of having a very thin UI layer in the browser. With more code running in
the browser, additional development tools would also need to be available in the browser.
A proper debugger running directly in the browser would probably be the first requirement.
The default CodeParadise debugger (which is still actually more an inspector on the call
stack) is helpful, but for Canyon apps in reality too minimalistic. In practice quite a
bit of 'printf debugging' turned out to be required.

Both apps are working and running smoothly, but initial development did cost some time.

When developing mobile apps without a 'standalone' requirement (i.e. where it is perfectly
normal to have an Internet connection), please give 'pure' CodeParadise a try. The Ionic
framework is available in CodeParadise and it brings quite a bit of value to the table.

If your 'standalone' requirement is also 'hard' feel free to try Canyon. Do know you
will have to put in some extra effort to make this workflow as easy as you're used to
(from a Smalltalk perspective).

Also feel free to reach out and discuss your requirements and what it means when using
Canyon as the main framework.

There are some alternatives for using Smalltalk in the browser too, which do allow the
creation of standalone mobile apps:

* [PharoJS](https://pharojs.org)
* [SmallJS](https://small-js.org)