Extension { #name : #IonRadioGroup }

{ #category : #'*CodeParadise-Canyon-App' }
IonRadioGroup >> valueForModel [

	"Convenience method used in binding Elements to a Model"

	^ self value
]

{ #category : #'*CodeParadise-Canyon-App' }
IonRadioGroup >> valueFromModel: anObject [

	"Convenience method used in binding Elements to a Model"

	| newValue |

	newValue := anObject ifNotNil: [ anObject asString ].

	"Only update if changed (to prevent ping-pong between Element and Model)"
	self valueForModel = newValue
		ifFalse: [ self value: newValue ]
]

{ #category : #'*CodeParadise-Canyon-App' }
IonRadioGroup >> whenChangedDo: aBlock for: anObject [

	"Convenience method used in binding Elements to a Model"

	^ self when: IonChangeEvent do: aBlock for: anObject
]
