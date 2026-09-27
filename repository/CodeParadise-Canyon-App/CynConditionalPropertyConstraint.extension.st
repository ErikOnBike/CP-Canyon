Extension { #name : #CynConditionalPropertyConstraint }

{ #category : #'*CodeParadise-Canyon-App' }
CynConditionalPropertyConstraint >> isApplicableIn: aModel [

	"Answer whether the receiver is applicable in the specified Model.
	I.e. if the receiver's condition is true for the Model."

	^ condition value: aModel
]

{ #category : #'*CodeParadise-Canyon-App' }
CynConditionalPropertyConstraint >> possibleValuesIn: aModel with: anObject [

	^ (self isApplicableIn: aModel)
		ifTrue: [ constraint possibleValuesIn: aModel with: anObject ]
		ifFalse: [ super possibleValuesIn: aModel with: anObject ]
]
