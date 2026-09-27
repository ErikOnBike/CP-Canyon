Class {
	#name : #CynIntervalPropertyConstraint,
	#superclass : #CynPropertyConstraint,
	#instVars : [
		'interval'
	],
	#category : #'CodeParadise-Canyon-Model-Constraints'
}

{ #category : #accessing }
CynIntervalPropertyConstraint class >> interval: anInterval [

	"Answer a new instance of the receiver with the specified Interval"

	^ self basicNew
		initializeWithInterval: anInterval ;
		yourself
]

{ #category : #'instance creation' }
CynIntervalPropertyConstraint class >> new [

	self errorNewReplacedBy: #interval:
]

{ #category : #initialization }
CynIntervalPropertyConstraint >> initializeWithInterval: anInterval [

	self initialize.

	interval := anInterval
]

{ #category : #accessing }
CynIntervalPropertyConstraint >> interval [

	^ interval
]

{ #category : #validating }
CynIntervalPropertyConstraint >> violationsForValue: aNumber in: aModel do: aBlock [

	"Validate the provided String is part of the interval"

	(aNumber isNil and: [ (interval includes: nil) not ])
		ifTrue: [ ^ aBlock value: #'constraint.required' ].

	(interval includes: aNumber)
		ifFalse: [ ^ aBlock value: (CynTextReference key: #'constraint.interval.outside' with: aNumber asString) ]
]
