Class {
	#name : #CynRestApiService,
	#superclass : #CynBaseRestApiService,
	#category : #'CodeParadise-Canyon-Data-Service'
}

{ #category : #'API - logging' }
CynRestApiService >> clientLogRecordFrom: aDictionary [

	"Answer a log record for the specified request body or nil if none can be provided"

	| level message |

	"Validate body info (without this info, no record)"
	level := aDictionary at: #level ifAbsent: [ ^ nil ].
	message := aDictionary at: #message ifAbsent: [ ^ nil ].

	"Answer the log record"
	^ {
		#timestamp -> CpJavaScriptDate timestampNow.
		#level -> level.
		#message -> ('Client log: ', message).
		#statusCode -> 0.
		#stack -> (aDictionary at: #stack ifAbsent: [ nil ]).
	} asDictionary
]

{ #category : #notifying }
CynRestApiService >> errorNotificationMailAccount [

	"Answer the mail account where notifications should be sent"

	^ config at: #errorNotificationMailAccount ifAbsent: [ nil ]
]

{ #category : #API }
CynRestApiService >> log: aRestRequest response: aRestResponse [

	"Log the client message.
	This endpoint is to be used for storing relevant client side events (including errors).

	Implementation:
	It is assumed this endpoint is called used the CpBrowserNavigator >> sendBeacon:data:
	method. This mechanism does not offer any means to add authentication data to the
	request header. Authentication is therefore done based on the body content.
	Beacon requests do not expect a result, therefore silently ignore any errors."

	<post: '/api/log'>
	<public>

	[ self notifyLog: (self writeClientLogFrom: aRestRequest) ] on: Error do: [ :error | "ignore errors" ].

	"Beacon requests do not expect a response"
	self sendEmptyResponse: aRestResponse
]

{ #category : #logging }
CynRestApiService >> logError: anError request: aRestRequest [

	^ self notifyLog: (super logError: anError request: aRestRequest)
]

{ #category : #logging }
CynRestApiService >> logInfoMessage: aString request: aRestRequest [

	"Do not log for logging API call"

	aRestRequest ifNotNil: [
		aRestRequest path asString = '/api/log'
			ifTrue: [ ^ nil ] ].

	^ super logInfoMessage: aString request: aRestRequest
]

{ #category : #notifying }
CynRestApiService >> notificationTimeout [

	"Answer the timeout before sending the same/similar notification again (in seconds).

	By default this is 30 minutes."

	^ config at: #notificationTimeout ifAbsent: [ 1800 ]
]

{ #category : #notifying }
CynRestApiService >> notificationWindow [

	"Answer the time frame in which a certain amount of notifications can be sent (in seconds).
	The amount is specified by #notificationWindowCount.

	By default this is 2 hours."

	^ config at: #notificationWindow ifAbsent: [ 7200 ]
]

{ #category : #notifying }
CynRestApiService >> notificationWindowCount [

	"Answer the amount of notifications which can be sent in a fixed time frame.
	The time frame is specified by #notificationWindow.

	By default this is 4."

	^ config at: #notificationWindowCount ifAbsent: [ 4 ]
]

{ #category : #notifying }
CynRestApiService >> notify: messageString statusCode: statusCodeInteger stack: stackString forLogId: logIdInteger [

	"Notify by sending a mail to the admin and then adding entry to the database"

	| notificationMessage |

	notificationMessage := self newMailMessage
		to: self errorNotificationMailAccount ;
		subject: 'Error in ', (self class nameWithoutPrefix withoutSuffix: 'RestApiService') ;
		html: ('<h1>Error: {1}</h1><h3>Statuscode: {2}</h3><h3>Stack trace:</h3><pre>{3}</pre>' format: { messageString . statusCodeInteger printString . stackString }) ;
		yourself.

	self sendMail: notificationMessage thenDo: [ :error :info |
		error ifNotNil: [ self errorCr: 'Failed to send notification: ', error printString ] ].

	logDatabase ifNil: [ ^ self ].

	[ logDatabase
		performOne: #addNotification
		statement: 'INSERT INTO notifications (timestamp, logId, statusCode, message) VALUES(:now, :logId, :statusCode, :message)'
		bind: {
			#now -> CpJavaScriptDate timestampNow.
			#logId -> logIdInteger.
			#statusCode -> statusCodeInteger.
			#message -> messageString } asDictionary
	] on: Error do: [ :error | self errorCr: 'Failed to store notification: ', error printString ]
]

{ #category : #notifying }
CynRestApiService >> notifyLog: anInteger [

	"Notify about the log entry.
	Answer the log id provided (since this methods is used to wrap existing logging requests)."

	| logRecord notificationCount recently |

	anInteger ifNil: [ ^ nil ].

	logDatabase ifNil: [ ^ anInteger ].

	self shouldNotify
		ifFalse: [ ^ anInteger ].

	"Retrieve log record"
	logRecord := logDatabase
		selectOne: #recentLogEntry
		statement: 'SELECT statusCode, message, stack FROM logs WHERE id=:id'
		bind: { #id -> anInteger } asDictionary.
	logRecord ifNil: [ ^ anInteger ].

	(self shouldNotifyStatusCode: (logRecord at: #statusCode))
		ifFalse: [ ^ anInteger ].

	"Check if a recent notification is made for a similar log entry.
	If recently notified, do not notify again."
	recently := CpJavaScriptDate timestampNow - self notificationTimeout.
	logDatabase
		exists: #notificationExists
		statement: 'SELECT id FROM notifications WHERE timestamp >= :recently AND statusCode=:statusCode AND message=:message'
		bind: {
			#recently -> recently.
			#statusCode -> (logRecord at: #statusCode).
			#message -> (logRecord at: #message) } asDictionary
		ifTrue: [ ^ anInteger ].

	"Check total amount of recent notifications"
	recently := CpJavaScriptDate timestampNow - self notificationWindow.
	notificationCount := logDatabase
		selectCount: #countRecentNotifications
		statement: 'SELECT count(*) FROM notifications WHERE timestamp >= :recently AND (statusCode>=500 OR statusCode=0)'
		bind: { #recently -> recently } asDictionary.

	"If too many notifications, do not notify again"
	notificationCount > self notificationWindowCount
		ifTrue: [ ^ anInteger ].

	"Do notify"
	self
		notify: (logRecord at: #message)
		statusCode: (logRecord at: #statusCode)
		stack: (logRecord at: #stack)
		forLogId: anInteger.

	^ anInteger
]

{ #category : #notifying }
CynRestApiService >> shouldNotify [

	^ self errorNotificationMailAccount isNotNil
]

{ #category : #notifying }
CynRestApiService >> shouldNotifyStatusCode: anInteger [

	"Only notify internal server errors, client errors (statusCode = 0) or forbidden errors
	(statusCode = 403). The latter is for an authenticated user to access an endpoint or
	resource which it is not allowed to. Typically this indicates a programming error.
	The 401 - Unauthorized error is not notified, because it represents failed login
	attempts or bots trying to access the API (which will happen often)."

	^ anInteger >= 500 or: [ anInteger = 0 or: [ anInteger = CpNodeJSRestForbiddenError ] ]
]

{ #category : #logging }
CynRestApiService >> updateLogResponse: aRestResponse [

	"Update the log entry with status code.
	Add notification for the entry."

	^ self notifyLog: (super updateLogResponse: aRestResponse)
]

{ #category : #'API - logging' }
CynRestApiService >> writeClientLogFrom: aRestRequest [

	"Write the client log from the request. The client send this log request using Beacon API.
	Validate the body contains a accessToken (which may already be expired, but should be known).
	Without an access token, ignore the log (otherwise there will be the opportunity to fill our
	logging DB with trash).
	Answer the id of the log row created (or nil if none is created)."

	| body logRecord |

	logDatabase ifNil: [ ^ nil ].

	body := aRestRequest jsonBody
		ifNil: [ ^ nil ].

	logRecord := (self clientLogRecordFrom: body)
		ifNil: [ ^ nil ].

	[
		^ logDatabase
			performOne: #insertClientLogRecord
			statement: 	'INSERT INTO logs (timestamp, level, message, statusCode, accountId, sessionId, stack) VALUES (:timestamp, :level, :message, :statusCode, :accountId, :sessionId, :stack)'
			bind: logRecord
	] on: Error do: [ :error |
		self warnCr: 'Failed to write log record: ', error printString.
		^ nil ]
]
