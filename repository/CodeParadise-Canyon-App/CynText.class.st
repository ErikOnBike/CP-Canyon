Class {
	#name : #CynText,
	#superclass : #CpTemplateComponent,
	#category : #'CodeParadise-Canyon-App-View'
}

{ #category : #'instance creation' }
CynText class >> labelText: aSymbol [

	"Answer a new instance with the specified text key and mark it as a label (will influence color,
	since Ionic is peculiair in handling label color)."

	^ self new
		attributeAt: #text put: aSymbol ;
		addClass: #label ;
		render
]

{ #category : #'web resources' }
CynText class >> style [

	<webResource: #css>

	^ ':host {
	display: inline;
}
:host(.label) {
	color: var(--canyon-label-color);
}'
]

{ #category : #'instance creation' }
CynText class >> text: aSymbol [

	^ self new
		attributeAt: #text put: aSymbol ;
		render
]

{ #category : #accessing }
CynText >> count [

	^ (self propertyAt: #count)
		ifNil: [
			(self attributeAt: #count)
				ifNotNil: [ :countString | countString asNumberOrNil ] ]
]

{ #category : #accessing }
CynText >> count: anInteger [

	self propertyAt: #count put: anInteger.

	self render
]

{ #category : #accessing }
CynText >> format [

	^ (self propertyAt: #format)
		ifNil: [
			(self attributeAt: #format)
				ifNotNil: [ :formatString | CpJavaScriptJSON parse: formatString ifFail: [ nil ] ] ]
]

{ #category : #accessing }
CynText >> format: aDictionary [

	self propertyAt: #format put: aDictionary.

	self render
]

{ #category : #accessing }
CynText >> index [

	^ (self propertyAt: #index)
		ifNil: [
			(self attributeAt: #index)
				ifNotNil: [ :indexString | indexString asNumberOrNil ] ]
]

{ #category : #accessing }
CynText >> index: anInteger [

	self propertyAt: #index put: anInteger.

	self render
]

{ #category : #initialization }
CynText >> initialize [

	super initialize.

	self render
]

{ #category : #'view - customization' }
CynText >> render [

	"Set text if value provided as attribute"

	self text ifNotNil: [ :text |
		self textContent: (self index
			ifNotNil: [ :index | CynPropertyEntity index: index text: text asSymbol format: self format ]
			ifNil: [
				self count
					ifNotNil: [ :count | CynPropertyEntity count: count text: text asSymbol format: self format ]
					ifNil: [ CynPropertyEntity text: text asSymbol format: self format ] ]) ]
]

{ #category : #accessing }
CynText >> text [

	^ (self propertyAt: #text)
		ifNil: [ self attributeAt: #text ]
]

{ #category : #accessing }
CynText >> text: aString [

	self propertyAt: #text put: aString.

	self render
]

{ #category : #'view - customization' }
CynText >> updateMultiLanguageText [

	self render
]
