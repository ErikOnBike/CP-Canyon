Class {
	#name : #BaselineOfCpCanyon,
	#superclass : #BaselineOf,
	#category : #BaselineOfCpCanyon
}

{ #category : #baselines }
BaselineOfCpCanyon >> baseline: spec [

	<baseline>

	spec for: #'common' do: [

		"Load dependencies"
		spec
			baseline: 'CodeParadise' with: [ spec repository: 'github://ErikOnBike/CodeParadise' ].

		"Packages"
		spec
			package: 'CodeParadise-Canyon-Model' with: [ spec requires: #('CodeParadise') ];
			package: 'CodeParadise-Canyon-Data' with: [ spec requires: #('CodeParadise-Canyon-Model') ];
			package: 'CodeParadise-Canyon-App' with: [ spec requires: #('CodeParadise-Canyon-Model') ];
			package: 'CodeParadise-Canyon-Development' with: [ spec requires: #('CodeParadise-Canyon-App') ].

		"Groups"
		spec 
			group: 'default' with: #( 'Core' 'Development' );

			group: 'Core' with: #( 'CodeParadise-Canyon-Model' 'CodeParadise-Canyon-Data' 'CodeParadise-Canyon-App' );
			group: 'Development' with: #( 'CodeParadise-Canyon-Development' ) ].
]
