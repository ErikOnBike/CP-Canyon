Extension { #name : #CynPropertyConstraint }

{ #category : #'*CodeParadise-Canyon-App' }
CynPropertyConstraint >> isApplicableIn: aModel with: anObject [

	"Answer whether the receiver is applicable in the specified Model and with the specified value"

	^ true
]

{ #category : #'*CodeParadise-Canyon-App' }
CynPropertyConstraint >> possibleValuesIn: aModel with: anObject [

	"Answer a Collection of (the limited set of) possible values for the receiver
	within the specified Model (can be conditional and therefore requires the Model)
	and specified value (can be optional and therefore requires the value).

	Answers nil if no set of possible values exists.

	This method should only answer a Collection if it is actually has limited set
	of values. Do NOT answer the full range of possible values for a String of 3
	Characters for example."

	^ nil
]
