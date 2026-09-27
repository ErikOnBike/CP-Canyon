Extension { #name : #CynOptionalPropertyConstraint }

{ #category : #'*CodeParadise-Canyon-App' }
CynOptionalPropertyConstraint >> isApplicableIn: aModel with: anObject [

	"Answer whether the receiver is applicable in the specified Model
	and with the specified value.

	I.e. if the Model has a value for the receiver."

	^ anObject isNotNil
]

{ #category : #'*CodeParadise-Canyon-App' }
CynOptionalPropertyConstraint >> possibleValuesIn: aModel with: anObject [

	^ (self isApplicableIn: aModel with: anObject)
		ifTrue: [ constraint possibleValuesIn: aModel with: anObject ]
		ifFalse: [ super possibleValuesIn: aModel with: anObject ]
]
