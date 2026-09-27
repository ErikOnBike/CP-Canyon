Extension { #name : #CynPropertyModel }

{ #category : #'*CodeParadise-Canyon-App' }
CynPropertyModel >> errorTextForPropertyAt: aSymbol [

	"Answer an error text for the specified property.
	The error text represents violations the user should 'fix'.
	If no errors are encountered, answer nil."

	| errorTextStream |

	self
		propertyViolationsAt: aSymbol
		do: [ :violation |

			"Add a space as separater between individual error texts"
			 errorTextStream
				ifNotNil: [ errorTextStream space ]
				ifNil: [ errorTextStream := WriteStream on: (String new: 80) ].

			"Add the error text for the current violation"
			errorTextStream nextPutAll: (self errorTextForViolation: violation) ].

	^ errorTextStream ifNotNil: [ errorTextStream contents ]
]

{ #category : #'*CodeParadise-Canyon-App' }
CynPropertyModel >> errorTextForViolation: aSymbolOrTextReference [

	"Answer an error text for the specified violation.
	The violation is represented by a Symbol or a CynTextReference.
	By default, the violation is looked up as text value."

	^ self class
		text: aSymbolOrTextReference
]

{ #category : #'*CodeParadise-Canyon-App' }
CynPropertyModel class >> index: anInteger text: aSymbol [

	"Answer the indexed text for the specified Symbol.

	Implementation:
	Subclasses should override this.
	For now it simply answers the Symbol."

	^ aSymbol
]

{ #category : #'*CodeParadise-Canyon-App' }
CynPropertyModel class >> keyForTextAspect: aString at: aSymbol [

	"Answer the key for the specified text aspect of the specified property.
	Answer nil if such an aspect is missing.

	The text aspect can for example be: 'label', 'placeholder', etc.

	Implementation:
	Since Models can inherit properties from a superclass, perform repeated
	requests on the superclass when no text is found yet.
	A value is not found, if the value retrieved is the same as the key."

	| key value |

	"Create key"
	key := (String streamContents: [ :stream |
		stream
			nextPutAll: 'app.' ;
			nextPutAll: aString ;
			nextPut: $. ;
			nextPutAll: self shortName ;
			nextPut: $. ;
			nextPutAll: aSymbol ]) asSymbol.

	"Retrieve value"
	value := self text: key.

	"If no value is found and not yet at root, try superclass"
	(value = key and: [ self ~~ CynPropertyModel ])
		ifTrue: [ key := self superclass keyForTextAspect: aString at: aSymbol ].

	"Answer nil if still not found (i.e. key = value)"
	^ (key isNotNil and: [ key ~= value ])
		ifTrue: [ key ]
]

{ #category : #'*CodeParadise-Canyon-App' }
CynPropertyModel >> keyForTextAspect: aString at: aSymbol [

	"Answer the specified text aspect of the specified property.
	Answer nil if such an aspect is missing.

	The text aspect can for example be: 'label', 'placeholder', etc."

	^ self class
		keyForTextAspect: aString at: aSymbol
]

{ #category : #'*CodeParadise-Canyon-App' }
CynPropertyModel class >> labelFor: propertySymbol at: selectionSymbol [

	"Answer the label for the specified selection of the specified property"

	^ self textAspect: #selection at: propertySymbol at: selectionSymbol
]

{ #category : #'*CodeParadise-Canyon-App' }
CynPropertyModel >> labelFor: propertySymbol at: key [

	"Answer the label for the specified selection of the specified property"

	^ self class
		labelFor: propertySymbol at: key
]

{ #category : #'*CodeParadise-Canyon-App' }
CynPropertyModel >> possibleValuesAndLabelsFor: aSymbol do: aBlock [

	"Evaluate the specified Block for all values (and labels) for the specified property"

	| sharedPossibleValues |

	"Find possible values shared between all matching property constraints"
	self class propertyConstraintsAt: aSymbol do: [ :each |
		(each possibleValuesIn: self with: (self rawAt: aSymbol)) ifNotNil: [ :possibleValues |
			sharedPossibleValues := sharedPossibleValues
				ifNotNil: [ sharedPossibleValues select: [ :value | possibleValues includes: value ] ]
				ifNil: [ possibleValues ] ] ].

	"Evaluate the Block for the possible values"
	sharedPossibleValues do: [ :each |
		aBlock
			value: each
			value: (self labelFor: aSymbol at: each) ]
]

{ #category : #'*CodeParadise-Canyon-App' }
CynPropertyModel >> propertyViolationsAt: aSymbol do: aBlock [

	"Evaluate the specified Block for each violation in the specified
	property of the receiver.
	The Block will be evaluated with a key (a Symbol or CynTextReference)
	representing the violation."

	self class propertyConstraintsAt: aSymbol do: [ :each |

		"Per constraint evaluate all violations. Use the 'long' form with
		the model, since conditional constraints require access to the model.
		Do NOT use #violationsIn:do: here."
		each violationsForProperty: aSymbol in: self do: aBlock ]
]

{ #category : #'*CodeParadise-Canyon-App' }
CynPropertyModel >> shortLabelAt: aSymbol [

	"Answer the short label of the specified property
	or the regular if no short label is provided"

	^ (self textAspect: #shortLabel at: aSymbol)
		ifNil: [ (self textAspect: #label at: aSymbol) ]
]

{ #category : #'*CodeParadise-Canyon-App' }
CynPropertyModel class >> shortName [

	"Answer the short name for the receiver.

	This short name is used (among others) in multi language keys."

	^ self nameWithoutPrefix uncapitalized
]

{ #category : #'*CodeParadise-Canyon-App' }
CynPropertyModel class >> text: aSymbol [

	"Answer the text for the specified Symbol.

	Implementation:
	Subclasses should override this.
	For now it simply answers the Symbol."

	^ aSymbol
]

{ #category : #'*CodeParadise-Canyon-App' }
CynPropertyModel class >> textAspect: aString at: aSymbol [

	^ self textAspect: aString at: aSymbol at: nil
]

{ #category : #'*CodeParadise-Canyon-App' }
CynPropertyModel >> textAspect: aString at: aSymbol [

	"Answer the specified text aspect of the specified property.
	Answer nil if such an aspect is missing.

	The text aspect can for example be: 'label', 'placeholder', etc."

	^ self class
		textAspect: aString at: aSymbol
]

{ #category : #'*CodeParadise-Canyon-App' }
CynPropertyModel class >> textAspect: aString at: aSymbol at: key [

	"Answer the specified text aspect of the specified property.
	Answer nil if such an aspect is missing.

	The text aspect can for example be: 'label', 'placeholder', etc.

	The specified key is optional (and used for aspect #selection).

	Implementation:
	Since Models can inherit properties from a superclass, perform repeated
	requests on the superclass when no text is found yet."

	| fullKey value |

	"Create full key"
	fullKey := (String streamContents: [ :stream |
		stream
			nextPutAll: 'app.' ;
			nextPutAll: aString ;
			nextPut: $. ;
			nextPutAll: self shortName ;
			nextPut: $. ;
			nextPutAll: aSymbol.
		key isSymbol
			ifTrue: [
				stream
					nextPut: $. ;
					nextPutAll: key ] ]) asSymbol.

	"Retrieve value"
	value := key isInteger
		ifTrue: [ self index: key text: fullKey ]
		ifFalse: [ self text: fullKey ].

	"If no label value is found and not yet at root, try superclass"
	(value = fullKey and: [ self ~~ CynPropertyModel ])
		ifTrue: [ value := self superclass textAspect: aString at: aSymbol at: key ].

	"Answer nil if still not found (i.e. key = value)"
	^ value = fullKey
		ifFalse: [ value ]
]
