Class {
	#name : 'BaselineOfCpCanyon',
	#superclass : 'BaselineOf',
	#category : 'BaselineOfCpCanyon'
}

{ #category : 'baselines' }
BaselineOfCpCanyon >> baseline: spec [

	<baseline>

	spec for: #'common' do: [

		"Load dependencies"
		spec
			baseline: 'CodeParadise' with: [ spec repository: 'github://ErikOnBike/CodeParadise' ] ].
]
