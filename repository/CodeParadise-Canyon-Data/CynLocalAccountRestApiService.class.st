"
I am a REST API service with some simple support for accounts.

I assume the following tables are present in the SQLite database:
```
CREATE TABLE IF NOT EXISTS accounts (
	id TEXT NOT NULL PRIMARY KEY,	/* Never shared with user(s) */
	createdAt INTEGER NOT NULL,
	updatedAt INTEGER,
	deletedAt INTEGER,
	activatedAt INTEGER,
	email TEXT NOT NULL UNIQUE,
	password TEXT NOT NULL,		/* Hash of course */
	settings TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS activations (
	id TEXT NOT NULL PRIMARY KEY,
	email TEXT NOT NULL,
	token TEXT NOT NULL,
	expiresAt INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS sessions (
	id TEXT NOT NULL PRIMARY KEY,
	createdAt INTEGER NOT NULL,
	updatedAt INTEGER,
	accountId TEXT NOT NULL,
	accessToken TEXT NOT NULL UNIQUE,
	expires TEXT NOT NULL		/* 'usage', 'day' or 'never' */
);
```
"
Class {
	#name : #CynLocalAccountRestApiService,
	#superclass : #CynRestApiService,
	#category : #'CodeParadise-Canyon-Data-Service'
}

{ #category : #testing }
CynLocalAccountRestApiService class >> isAbstractTag [

	"The method is present to indicate the receiver is abstract.
	This method will NOT be evaluated to decide if the receiver is abstract."
]

{ #category : #API }
CynLocalAccountRestApiService >> activateAccount: aRestRequest response: aRestResponse [

	"Activate Account within Accounts collection"

	<post: '/api/accounts?action=activate'>
	<public>

	| body activateAccountToken accountId accessToken |

	body := (aRestRequest jsonBody) ifNil: [ self errorNoBody ].
	activateAccountToken := self extractNewObject: CynActivateAccountToken fromBody: body.

	accountId := self activateAccountUsingToken: activateAccountToken.

	"Create session and store access token in response header"
	accessToken := self createSessionForAccountId: accountId.
	aRestResponse setHeaderWithName: #'cp-access-token' value: accessToken.

	self sendEmptyResponse: aRestResponse
]

{ #category : #'API - accounts' }
CynLocalAccountRestApiService >> activateAccountUsingToken: anActivateAccountToken [

	"Activate the Account belonging to the specified Token.
	Answer the id of the Account activated."

	| now activation account |

	now := CpJavaScriptDate timestampNow.

	"Get the activation for the supplied token"
	activation := modelDatabase
		selectOne: #getActivation
		statement: 'SELECT id, email, expiresAt FROM tokens WHERE token=:token AND task=''activate'''
		bind: { #token -> anActivateAccountToken token } asDictionary.

	"No match for token"
	activation ifNil: [ ^ self errorTokenNotFound ].

	"Get account for the specified token"
	account := modelDatabase
		selectOne: #getActivationAccount
		statement: 'SELECT id, activatedAt FROM accounts WHERE email=:email AND deletedAt IS NULL'
		bind: { #email -> (activation at: #email) } asDictionary.

	"No match for account"
	account ifNil: [ ^ self errorTokenNotFound ].

	"Check if account is already activated, then we're done"
	(account at: #activatedAt)
		ifNotNil: [ ^ account at: #id ].

	"Check if token is already expired (okay to provide answer, since token is secret value anyway and can't be guessed)"
	(activation at: #expiresAt) < now
		ifTrue: [ ^ self errorTokenExpired ].

	"Mark account as activated"
	modelDatabase
		performOne: #activateAccount
		statement: 'UPDATE accounts SET activatedAt=:now, updatedAt=:now WHERE id=:id AND activatedAt IS NULL'
		bind: {
			#now -> now.
			#id -> (account at: #id) } asDictionary.

	"Remove all older activations (no longer needed). Keep the one used, because people sometimes accidentally use it again."
	modelDatabase
		performMulti: #removeOldActivations
		statement: 'DELETE FROM tokens WHERE email=:email AND task=''activate'' AND id<>:id'
		bind: {
			#id -> (activation at: #id).
			#email -> (activation at: #email) } asDictionary.

	self mailActivatedMailMessageTo: (activation at: #email).

	^ account at: #id
]

{ #category : #'API - accounts' }
CynLocalAccountRestApiService >> activatedMailMessage [

	^ self newMailMessage
		subject: 'Account is ready' ;
		text: ('Your account is ready to be used!') ;
		yourself
]

{ #category : #'API - accounts' }
CynLocalAccountRestApiService >> activationTokenMailMessageWith: aString [

	^ self newMailMessage
		subject: 'Activation code' ;
		text: ('Your activation code is: {1}' format: { aString }) ;
		html: ('Your <i>activation code</i> is <code>{1}</code>' format: { aString }) ;
		yourself
]

{ #category : #'API - accounts' }
CynLocalAccountRestApiService >> alreadyCreatedMailMessage [

	^ self newMailMessage
		subject: 'Account already created' ;
		text: ('An attempt was made to create an account belonging to this email address, but the account is already created.') ;
		yourself
]

{ #category : #logging }
CynLocalAccountRestApiService >> clientLogRecordFrom: aDictionary [

	| logRecord accessToken session |

	logRecord := (super clientLogRecordFrom: aDictionary)
		ifNil: [ ^ nil ].

	"Validate the access token is valid (but may be expired, so no check on existance)"
	accessToken := aDictionary at: #accessToken ifAbsent: [ ^ nil ].
	(CynTokenPropertyConstraint isValidValue: accessToken)
		ifFalse: [ ^ nil ].

	"Retrieve session (or nil if none exists, which is probably an expired session)"
	session := modelDatabase
		selectOne: #sessionForLogging
		statement: 'SELECT id, accountId FROM sessions WHERE accessToken=:accessToken'
		bind: { #accessToken -> accessToken } asDictionary.

	"Explicitly add accont and session id (even if nil)"
	logRecord
		at: #accountId put: (session ifNotNil: [ session at: #accountId ]) ;
		at: #sessionId put: (session ifNotNil: [ session at: #id ]).

	^ logRecord
]

{ #category : #'API - accounts' }
CynLocalAccountRestApiService >> createAccount: anAccount [

	"Create a new Account"

	| existingAccount id passwordHash |

	"Read account for specfied email address"
	existingAccount := modelDatabase
		selectOne: #getExistingAccountForCreate
		statement: 'SELECT activatedAt FROM accounts WHERE email=:email'
		bind: { #email -> anAccount email } asDictionary.

	"Handle the situation that an account already exists"
	existingAccount ifNotNil: [

		"If this Account is not activated yet, send new activation token."
		"If this Account is already activated send mail to explain the
		account already exists (a wrong doer will not see either situations
		and can therefore not conclude if the account is existing)."
		(existingAccount at: #activatedAt)
			ifNotNil: [ self mailAlreadyCreatedMailMessageTo: anAccount email ]
			ifNil: [ self createActivationTokenForAccount: anAccount ].

		^ self ].

	"Create new Account"
	id := self newId.
	passwordHash := self createPasswordHashFrom: anAccount password.

	modelDatabase
		performOne: #insertAccount
		statement: 'INSERT INTO accounts (id, createdAt, email, password, settings) VALUES(:id, :now, :email, :password, :settings)'
		bind: {
			#id -> id.
			#now -> CpJavaScriptDate timestampNow.
			#email -> anAccount email.
			#password -> passwordHash.
			#settings -> '{}' } asDictionary.

	self createActivationTokenForAccount: anAccount
]

{ #category : #API }
CynLocalAccountRestApiService >> createAccount: aRestRequest response: aRestResponse [

	"Add a new Account to the Accounts collection.

	Implementation:
	Always answer empty result, so wrong-doer can't conclude account exists based on result."

	<post: '/api/accounts'>
	<public>

	| body account |

	body := (aRestRequest jsonBody) ifNil: [ self errorNoBody ].
	account := self extractNewObject: CynRegisterAccount fromBody: body.

	self createAccount: account.

	self sendEmptyResponse: aRestResponse
]

{ #category : #'API - accounts' }
CynLocalAccountRestApiService >> createActivationTokenForAccount: anAccount [

	"Create an Activation record for the specified Account"

	| id token expiresAt |

	id := self newId.
	token := self newToken.
	expiresAt := CpJavaScriptDate timestampNowDeltaMinutes: 30.

	modelDatabase
		performOne: #createActivation
		statement: 'INSERT INTO tokens (id, task, email, token, expiresAt) VALUES(:id, ''activate'', :email, :token, :expiresAt)'
		bind: {
			#id -> id.
			#email -> anAccount email.
			#token -> token.
			#expiresAt -> expiresAt } asDictionary.

	self mailActivationToken: token to: anAccount email
]

{ #category : #'API - password' }
CynLocalAccountRestApiService >> createPasswordHashFrom: aString [

	"Answer a password hash (a hex String consisting of a '<salt><hash>' where the salt is 32 hex-characters)"

	^ self hashPassword: aString usingSalt: ((self crypto randomBytes: 16) toStringEncoding: #hex)
]

{ #category : #'API - accounts' }
CynLocalAccountRestApiService >> createPasswordResetTokenForAccount: anAccount [

	"Create an Forgotten record for the specified Account"

	| id token expiresAt |

	id := self newId.
	token := self newToken.
	expiresAt := CpJavaScriptDate timestampNowDeltaMinutes: 30.

	modelDatabase
		performOne: #createPasswordReset
		statement: 'INSERT INTO tokens (id, task, email, token, expiresAt) VALUES(:id, ''password'', :email, :token, :expiresAt)'
		bind: {
			#id -> id.
			#email -> anAccount email.
			#token -> token.
			#expiresAt -> expiresAt } asDictionary.

	self mailPasswordResetToken: token to: anAccount email
]

{ #category : #'API - sessions' }
CynLocalAccountRestApiService >> createSessionForAccountId: aString [

	"Create session with default expiration period"

	^ self createSessionForAccountId: aString expires: #day
]

{ #category : #'API - sessions' }
CynLocalAccountRestApiService >> createSessionForAccountId: accountIdString expires: expiresString [

	| id accessToken |

	id := self newId.
	accessToken := self newToken.

	modelDatabase
		performOne: #createSession
		statement: 'INSERT INTO sessions (id, createdAt, accountId, accessToken, expires) VALUES(:id, :now, :accountId, :accessToken, :expires)'
		bind: {
			#id -> id.
			#now -> CpJavaScriptDate timestampNow.
			#accountId -> accountIdString.
			#accessToken -> accessToken.
			#expires -> expiresString } asDictionary.

	^ accessToken
]

{ #category : #errors }
CynLocalAccountRestApiService >> errorInvalidLogin [

	CpNodeJSRestUnauthorizedError signal: 'Credentials provided do not match an active account'
]

{ #category : #errors }
CynLocalAccountRestApiService >> errorNonActivatedAccountDuringLogin [

	"This error should only be signalled if the account is validated (username/password match),
	because otherwise we might provide too much information to a possible wrong do-er."

	CpNodeJSRestConflictError signal: 'Account not activated'
]

{ #category : #errors }
CynLocalAccountRestApiService >> errorTokenExpired [

	CpNodeJSRestUnprocessableEntityError signal: 'Token is expired'
]

{ #category : #errors }
CynLocalAccountRestApiService >> errorTokenNotFound [

	CpNodeJSRestNotFoundError signal: 'Token not found'
]

{ #category : #'API - authorization' }
CynLocalAccountRestApiService >> getSessionForRequest: aRestRequest [

	| accessToken |

	"Retrieve access token from the request, otherwise request is not authorized"
	accessToken := (aRestRequest headerAt: #authorization)
		ifNotNil: [ :header | header withoutPrefix: 'Bearer ' ]
		ifNil: [ ^ nil ].

	(CynTokenPropertyConstraint isValidValue: accessToken)
		ifFalse: [ ^ nil ].

	"Find the session for this access token (which has an active account attached).
	Answer a (minimal) expired session if none is found (to distinguish between invalid or no access token)."
	^ (modelDatabase
		selectOne: #getSessionByAccessToken
		statement: 'SELECT id, accountId, createdAt, updatedAt, expires FROM sessions WHERE accessToken=:accessToken AND EXISTS (SELECT id FROM accounts WHERE id=accountId AND activatedAt IS NOT NULL AND deletedAt IS NULL)'
		bind: { #accessToken -> accessToken } asDictionary) ifNil: [ { #expires -> #usage. #updatedAt -> (CpJavaScriptDate timestampNowDeltaDays: -1) } asDictionary ]
]

{ #category : #'API - password' }
CynLocalAccountRestApiService >> hashPassword: plainTextPassword usingSalt: saltString [

	"Answer a hash by performing a Password-Based Key Derivation Function 2 (PBKDF2) on the specified plain text password.
	The hash is a hex String consisting of '<salt><hash>'."

	^ saltString, ((self crypto
		pbkdf2Password: plainTextPassword
		salt: saltString
		iterations: 100000
		keylen: 64
		digest: #sha512) toStringEncoding: #hex)
]

{ #category : #logging }
CynLocalAccountRestApiService >> insertLogStatement [

	^ 'INSERT INTO logs (timestamp, level, message, accountId, sessionId, statusCode) VALUES (:timestamp, :level, :message, :accountId, :sessionId, 0)'
]

{ #category : #'API - authorization' }
CynLocalAccountRestApiService >> isAdminAccount: aString [

	"Answer a Boolean stating whether the supplied account ID is for an admin user"

	^ false
]

{ #category : #'API - sessions' }
CynLocalAccountRestApiService >> isExpiredSession: aSession [

	"Answer whether the session (a Dictionary) is expired.

	Implementation:
	The field #expires can be:
		#never - session never expires
		#day - session expires the next day (when no longer kept alive by regular usage, see below)
		#usage - session expires if the API is not used for a certain amount of time (see #sessionExpirationDuration)

	When a session expires the next day, it can in fact be kept alive unlimitedly IF the user keeps using the API.
	Same holds for #usage of course."

	| expires now createdAt updatedAt |

	"Never expiring sessions, never expire ;-)"
	expires := aSession at: #expires.
	expires = #never
		ifTrue: [ ^ false ].

	"Check for recent activity (both day and usage)"
	now := CpJavaScriptDate timestampNow.
	updatedAt := (aSession at: #updatedAt)
		ifNil: [ aSession at: #createdAt ].
	updatedAt + self sessionExpirationDuration > now
		ifTrue: [ ^ false ].

	"Check for expiring the next day"
	expires = #day
		ifTrue: [
			"Check if 'createdAt' and 'now' are still on the same day"
			createdAt := aSession at: #createdAt.
			(createdAt // CpJavaScriptDate dayInSeconds) = (now // CpJavaScriptDate dayInSeconds)
				ifTrue: [ ^ false ] ].

	^ true
]

{ #category : #logging }
CynLocalAccountRestApiService >> logRecordFromError: anError request: aRestRequest [

	| session |

	session := aRestRequest ifNotNil: [ self getSessionForRequest: aRestRequest ].

	^ (super logRecordFromError: anError request: aRestRequest)
		at: #sessionId put: (session ifNotNil: [ session at: #sessionId ifAbsent: [ nil ] ]) ;
		at: #accountId put: (session ifNotNil: [ session at: #accountId ifAbsent: [ nil ] ]) ;
		yourself
]

{ #category : #logging }
CynLocalAccountRestApiService >> logRecordFromRequest: aRestRequest [

	| session |

	session := aRestRequest ifNotNil: [ self getSessionForRequest: aRestRequest ].

	^ (super logRecordFromRequest: aRestRequest)
		at: #sessionId put: (session ifNotNil: [ session at: #sessionId ifAbsent: [ nil ] ]) ;
		at: #accountId put: (session ifNotNil: [ session at: #accountId ifAbsent: [ nil ] ]) ;
		yourself
]

{ #category : #API }
CynLocalAccountRestApiService >> login: aRestRequest response: aRestResponse [

	<post: '/api/accounts?action=login'>
	<public>

	| body account storedAccount accessToken |

	body := (aRestRequest jsonBody) ifNil: [ self errorNoBody ].
	account := self extractNewObject: CynLoginAccount fromBody: body.

	"Precaution to not divulge more information than needed"
	[
		"Read account"
		storedAccount := modelDatabase
			selectOne: #login
			statement: 'SELECT id, email, password, settings, activatedAt FROM accounts WHERE deletedAt IS NULL AND email=:email'
			bind: {
				#email -> account email } asDictionary.

		storedAccount ifNil: [ self errorInvalidLogin ].

		"Validate password"
		(self matchPassword: account password withHash: (storedAccount at: #password))
			ifFalse: [ self errorInvalidLogin ].

		"Merge the stored account id"
		account id: (storedAccount at: #id).
	] on: Error do: [ :err | self errorInvalidLogin ].

	"Validate activated (perform outside error handler above)"
	(storedAccount at: #activatedAt)
		ifNil: [ self errorNonActivatedAccountDuringLogin ].

	"Create session and store access token in response header"
	accessToken := self createSessionForAccountId: account id expires: account expires.
	aRestResponse setHeaderWithName: #'cp-access-token' value: accessToken.

	"Send response to indicate success"
	self send: { #success -> true . #settings -> (CpJavaScriptJSON parse: (storedAccount at: #settings)) } asDictionary response: aRestResponse
]

{ #category : #'API - accounts' }
CynLocalAccountRestApiService >> mailActivatedMailMessageTo: emailString [

	self mail: self activatedMailMessage to: emailString
]

{ #category : #'API - accounts' }
CynLocalAccountRestApiService >> mailActivationToken: tokenString to: emailString [

	self mail: (self activationTokenMailMessageWith: tokenString) to: emailString
]

{ #category : #'API - accounts' }
CynLocalAccountRestApiService >> mailAlreadyCreatedMailMessageTo: emailString [

	self mail: self alreadyCreatedMailMessage to: emailString
]

{ #category : #'API - accounts' }
CynLocalAccountRestApiService >> mailPasswordChangedMailMessageTo: emailString [

	self mail: self passwordChangedMailMessage to: emailString
]

{ #category : #'API - accounts' }
CynLocalAccountRestApiService >> mailPasswordResetToken: tokenString to: emailString [

	self mail: (self passwordResetTokenMailMessageWith: tokenString) to: emailString
]

{ #category : #'API - password' }
CynLocalAccountRestApiService >> matchPassword: plainTextPassword withHash: hashedPassword [

	"Answer whether the specified password matches the hashed password specified.

	Implementation:
	The hashed password consists of: 16 byte hex salt string followed by hashed password (PBKDF2).
	Therefore extract the first 32 characters (salt string is hex string of 16 bytes) to recreate
	the salt. Then perform hashing algorithm to create a hashed password value.
	Finally, check that value against the previously stored hashed value."

	| salt hash |

	salt := hashedPassword first: 32.

	hash := self hashPassword: plainTextPassword usingSalt: salt.

	^ hashedPassword = hash
]

{ #category : #'API - accounts' }
CynLocalAccountRestApiService >> passwordChangedMailMessage [

	^ self newMailMessage
		subject: 'Account password is reset' ;
		text: ('Your account''s password is reset!') ;
		yourself
]

{ #category : #API }
CynLocalAccountRestApiService >> passwordForgottenAccount: aRestRequest response: aRestResponse [

	"Activate Account within Accounts collection"

	<post: '/api/accounts?action=password-forgotten'>
	<public>

	| body account |

	body := (aRestRequest jsonBody) ifNil: [ self errorNoBody ].
	account := self extractNewObject: CynPasswordForgottenAccount fromBody: body.

	self sendPasswordResetMailToAccount: account.

	self sendEmptyResponse: aRestResponse
]

{ #category : #API }
CynLocalAccountRestApiService >> passwordResetAccount: aRestRequest response: aRestResponse [

	"Reset password of Account within Accounts collection"

	<post: '/api/accounts?action=password-reset'>
	<public>

	| body changePasswordToken |

	body := (aRestRequest jsonBody) ifNil: [ self errorNoBody ].
	changePasswordToken := self extractNewObject: CynChangePasswordToken fromBody: body.

	self passwordResetAccountUsingToken: changePasswordToken.

	self sendEmptyResponse: aRestResponse
]

{ #category : #'API - accounts' }
CynLocalAccountRestApiService >> passwordResetAccountUsingToken: aChangePasswordToken [

	"Reset password for the Account belonging to the specified in the Token"

	| now passwordHash reset account |

	now := CpJavaScriptDate timestampNow.
	passwordHash := self createPasswordHashFrom: aChangePasswordToken password.

	"Get the reset for the supplied token"
	reset := modelDatabase
		selectOne: #getReset
		statement: 'SELECT id, email, expiresAt FROM tokens WHERE token=:token AND task=''password'''
		bind: { #token -> aChangePasswordToken token } asDictionary.

	"No match for token"
	reset ifNil: [ ^ self errorTokenNotFound ].

	"Get account for the specified token"
	account := modelDatabase
		selectOne: #getResetAccount
		statement: 'SELECT id FROM accounts WHERE email=:email AND deletedAt IS NULL'
		bind: { #email -> (reset at: #email) } asDictionary.

	"No match for account"
	account ifNil: [ ^ self errorTokenNotFound ].

	"Token already expired (okay to provide answer, since token is secret value anyway and can't be guessed)"
	(reset at: #expiresAt) < now
		ifTrue: [ ^ self errorTokenExpired ].

	"Store the new password"
	modelDatabase
		performOne: #passwordResetAccount
		statement: 'UPDATE accounts SET updatedAt=:now, password=:passwordHash WHERE email=:email AND deletedAt IS NULL'
		bind: {
			#now -> now.
			#passwordHash -> passwordHash.
			#email -> (reset at: #email) } asDictionary.

	"Remove all older resets (no longer needed). Keep the one used, because people sometimes accidentally use it again."
	modelDatabase
		performMulti: #removeResets
		statement: 'DELETE FROM tokens WHERE email=:email AND task=''password'' AND id<>:id'
		bind: {
			#id -> (reset at: #id).
			#email -> (reset at: #email) } asDictionary.

	self mailPasswordChangedMailMessageTo: (reset at: #email)
]

{ #category : #'API - accounts' }
CynLocalAccountRestApiService >> passwordResetTokenMailMessageWith: aString [

	^ self newMailMessage
		subject: 'Password reset code' ;
		text: ('Your password reset code is: {1}' format: { aString }) ;
		html: ('Your <i>password reset code</i> is <code>{1}</code>' format: { aString }) ;
		yourself
]

{ #category : #API }
CynLocalAccountRestApiService >> ping: aRestRequest response: aRestResponse [

	"Ping to check on liveness"

	<get: '/api/ping/hello'>
	<public>

	"Validate the access token (if supplied)"
	(aRestRequest hasHeaderAt: #authorization)
		ifTrue: [ self validateAuthorizedRequest: aRestRequest ].

	super ping: aRestRequest response: aRestResponse
]

{ #category : #'API - accounts' }
CynLocalAccountRestApiService >> sendPasswordResetMailToAccount: anAccount [

	"Send a password reset mail the specified Account.

	Implementation:
	If account does not exist, ignore it. Do not let caller know whether
	account exists or not. It is okay if account is not activated yet."

	modelDatabase
		exists: #passwordResetAccountExists
		statement: 'SELECT id FROM accounts WHERE email=:email AND deletedAt IS NULL'
		bind: { #email -> anAccount email } asDictionary
		ifFalse: [ ^ self ].

	self createPasswordResetTokenForAccount: anAccount
]

{ #category : #accessing }
CynLocalAccountRestApiService >> sessionExpirationDuration [

	"Answer the duration before a session's access token expires (in seconds).

	By default this is 30 minutes."

	^ config at: #sessionExpirationDuration ifAbsent: [ 1800 ]
]

{ #category : #'API - settings' }
CynLocalAccountRestApiService >> updateSettings: aDictionary forAccountId: aString [

	| settings |

	modelDatabase performInTransaction: [
		| accountInfo |

		"Read settings"
		accountInfo := modelDatabase
			selectOne: #getSettings
			statement: 'SELECT settings, updatedAt FROM accounts WHERE id=:accountId'
			bind: {
				#accountId -> aString } asDictionary.
		accountInfo ifNil: [ CpNodeJSRestBadRequestError signal ].

		settings := [ CpJavaScriptJSON parse: (accountInfo at: #settings) ] on: Error do: [ :error |
			self logError: error.
			self errorCr: 'Failed to parse account settings ', error printString.
			self traceCr: 'Settings: ', (accountInfo at: #settings) printString.

			"Start with empty settings"
			Dictionary new ].

		"Update settings"
		aDictionary keysAndValuesDo: [ :key :value |
			value
				ifNotNil: [ settings at: key put: value ]
				ifNil: [ settings removeKey: key ifAbsent: [ "ignore" ] ] ].

		"Write settings"
		modelDatabase
			performOne: #updateSettings
			statement: 'UPDATE accounts SET settings=:settings WHERE id=:accountId AND updatedAt=:updatedAt'
			bind: {
				#settings -> (CpJavaScriptJSON stringify: settings).
				#accountId -> aString.
				#updatedAt -> (accountInfo at: #updatedAt) } asDictionary ].

	^ settings
]

{ #category : #API }
CynLocalAccountRestApiService >> updateSettings: aRestRequest response: aRestResponse [

	"Patch the settings using the following mechanism:
		fields which are non-nil are set to their specified value.
		fields which are nil are removed."

	<patch: '/api/accounts/current/settings'>

	| settings |

	settings := (aRestRequest jsonBody) ifNil: [ self errorNoBody ].

	self send: (self updateSettings: settings forAccountId: aRestRequest accountId) response: aRestResponse
]

{ #category : #'API - authorization' }
CynLocalAccountRestApiService >> validateAuthorizedAdminRequest: aRestRequest [

	"Default authorization handler for admin endpoints"

	self validateAuthorizedRequest: aRestRequest.

	(self isAdminAccount: (aRestRequest propertyAt: #accountId))
		ifFalse: [ CpNodeJSRestForbiddenError signal ]
]

{ #category : #'API - authorization' }
CynLocalAccountRestApiService >> validateAuthorizedRequest: aRestRequest [

	"Default authorization handler for non-public endpoints"

	| session |

	session := self getSessionForRequest: aRestRequest.
	session ifNil: [ CpNodeJSRestForbiddenError signal ].

	"Check for expiration (if expired, signal Unauthorized!)"
	(self isExpiredSession: session)
		ifTrue: [ CpNodeJSRestUnauthorizedError signal ].

	"Update the session"
	modelDatabase
		performOne: #updateSession
		statement: 'UPDATE sessions SET updatedAt=:now WHERE id=:id'
		bind: {
			#id -> (session at: #id).
			#now -> CpJavaScriptDate timestampNow } asDictionary.

	"Store the accountId for later usage"
	aRestRequest propertyAt: #accountId put: (session at: #accountId)
]
