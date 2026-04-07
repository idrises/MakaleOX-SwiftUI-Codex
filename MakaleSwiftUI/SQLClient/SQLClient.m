
//  SQLClient.m
//  SQLClient
//
//  Created by Martin Rybak on 10/4/13.
//  Copyright (c) 2013 Martin Rybak. All rights reserved.
//

#import "SQLClient.h"
#import "sybfront.h"
#import "sybdb.h"
#import "syberror.h"

int const SQLClientDefaultTimeout = 5;
int const SQLClientDefaultQueryTimeout = 5;
NSString* const SQLClientDefaultCharset = @"UTF-8";
NSString* const SQLClientWorkerQueueName = @"com.martinrybak.sqlclient";
NSString* const SQLClientDelegateError = @"Delegate must be set to an NSObject that implements the SQLClientDelegate protocol";
NSString* const SQLClientRowIgnoreMessage = @"Ignoring unknown row type";

struct COL
{
	char* name;
	char* buffer;
	int type;
	int size;
	int status;
};

static void SQLClientFreeColumns(struct COL *columns, int ncols)
{
	if (columns == NULL) {
		return;
	}

	for (int i = 0; i < ncols; i++) {
		free(columns[i].buffer);
	}
	free(columns);
}

static int SQLClientStringBufferSizeForColumnType(int type, int columnSize)
{
	int safeColumnSize = columnSize > 0 ? columnSize : 0;

	switch (type) {
		case SYBBINARY:
		case SYBVARBINARY:
		case SYBIMAGE:
			if (safeColumnSize > 0) {
				return (safeColumnSize * 2) + 1;
			}
			return 256;

		case SYBCHAR:
		case SYBVARCHAR:
		case SYBTEXT:
		case SYBNVARCHAR:
		case SYBNTEXT:
			if (safeColumnSize > 0) {
				return (safeColumnSize * 4) + 1;
			}
			return 256;

		default:
			if (safeColumnSize > 0) {
				int expandedSize = (safeColumnSize * 4) + 1;
				return expandedSize > 64 ? expandedSize : 64;
			}
			return 256;
	}
}

static void SQLClientFreeCString(char **buffer)
{
	if (buffer == NULL || *buffer == NULL) {
		return;
	}

	size_t length = strlen(*buffer);
	if (length > 0) {
		memset(*buffer, 0, length);
	}
	free(*buffer);
	*buffer = NULL;
}

@interface SQLClient ()

@property (nonatomic, copy, readwrite) NSString* host;
@property (nonatomic, copy, readwrite) NSString* username;
@property (nonatomic, copy, readwrite) NSString* database;
- (NSOperationQueue *)effectiveCallbackQueue;

@end

@implementation SQLClient
{
	LOGINREC* login;
	DBPROCESS* connection;
	char* _password;
	char* _hostCString;
	char* _usernameCString;
	char* _databaseCString;
	char* _charsetCString;
}

#pragma mark - NSObject

//Initializes the FreeTDS library and sets callback handlers
- (id)init
{
    if (self = [super init])
    {
        //Initialize the FreeTDS library
        if (dbinit() == FAIL)
			return nil;
		
		//Initialize SQLClient
		self.timeout = SQLClientDefaultTimeout;
		self.charset = SQLClientDefaultCharset;
		self.callbackQueue = [NSOperationQueue currentQueue];
		self.workerQueue = [[NSOperationQueue alloc] init];
		self.workerQueue.name = SQLClientWorkerQueueName;
		
        //Set FreeTDS callback handlers
        dberrhandle(err_handler);
        dbmsghandle(msg_handler);
    }
    return self;
}

//Exits the FreeTDS library
- (void)dealloc
{
    dbexit();
}

#pragma mark - Public

+ (instancetype)sharedInstance
{
    static SQLClient* sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void)connect:(NSString*)host
	   username:(NSString*)username
	   password:(NSString*)password
	   database:(NSString*)database
	 completion:(void (^)(BOOL success))completion
{
	//Save inputs
	self.host = host;
	self.username = username;
	self.database = database;

	/*
	Copy password into a global C string. This is because in connectionSuccess: and connectionFailure:,
	dbloginfree() will attempt to overwrite the password in the login struct with zeroes for security.
	So it must be a string that stays alive until then. Passing in [password UTF8String] does not work because:
		 
	"The returned C string is a pointer to a structure inside the string object, which may have a lifetime
	shorter than the string object and will certainly not have a longer lifetime. Therefore, you should
	copy the C string if it needs to be stored outside of the memory context in which you called this method."
	https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSString_Class/Reference/NSString.html#//apple_ref/occ/instm/NSString/UTF8String
	 */
	SQLClientFreeCString(&_password);
	SQLClientFreeCString(&_hostCString);
	SQLClientFreeCString(&_usernameCString);
	SQLClientFreeCString(&_databaseCString);
	SQLClientFreeCString(&_charsetCString);
	_password = strdup([password UTF8String]);
	_hostCString = strdup([host UTF8String]);
	_usernameCString = strdup([username UTF8String]);
	_databaseCString = database.length > 0 ? strdup([database UTF8String]) : NULL;
	_charsetCString = strdup([self.charset UTF8String]);
	
	//Connect to database on worker queue
	[self.workerQueue addOperationWithBlock:^{
	
		//Set login timeout
		dbsetlogintime(self.timeout);
		
		//Initialize login struct
        if ((self->login = dblogin()) == FAIL)
			return [self connectionFailure:completion];
		
		//Populate login struct
        DBSETLUSER(self->login, self->_usernameCString);
        DBSETLPWD(self->login, self->_password);
        DBSETLHOST(self->login, self->_hostCString);
        DBSETLCHARSET(self->login, self->_charsetCString);
		if (self->_databaseCString != NULL) {
	        DBSETLDBNAME(self->login, self->_databaseCString);
		}
		
		//Connect to database server
        if ((self->connection = dbopen(self->login, [self.host UTF8String])) == NULL)
			return [self connectionFailure:completion];
	
		//Success!
		[self connectionSuccess:completion];
	}];
}

- (BOOL)connected
{
	return !dbdead(connection);
}

// TODO: how to get number of records changed during update or delete
// TODO: how to handle SQL stored procedure output parameters
- (void)execute:(NSString*)sql completion:(void (^)(NSArray* results))completion
{
	//Execute query on worker queue
	[self.workerQueue addOperationWithBlock:^{
		
		//Set query timeout
		dbsettime(self.timeout);
		
		//Prepare SQL statement
        dbcmd(self->connection, [sql UTF8String]);
		
		//Execute SQL statement
        if (dbsqlexec(self->connection) == FAIL)
			return [self executionFailure:completion];
		
		//Create array to contain the tables
		NSMutableArray* output = [[NSMutableArray alloc] init];
		
		struct COL* columns;
		struct COL* pcol;
		int bindResult;
		
		//Loop through each table
	        while (dbresults(self->connection) != NO_MORE_RESULTS)
		{
			int ncols;
			int row_code;
						
			//Create array to contain the rows for this table
			NSMutableArray* table = [[NSMutableArray alloc] init];
			
			//Get number of columns
            ncols = dbnumcols(self->connection);
			
				//Allocate C-style array of COL structs
				if ((columns = calloc(ncols, sizeof(struct COL))) == NULL)
					return [self executionFailure:completion];
			
			//Bind the column info
			for (pcol = columns; pcol - columns < ncols; pcol++)
			{
				//Get column number
				int c = (int) (pcol - columns + 1) ;
				
				//Get column metadata
                pcol->name = dbcolname(self->connection, c);
                pcol->type = dbcoltype(self->connection, c);
				if (!dbwillconvert(pcol->type, SYBCHAR))
				{
					SQLClientFreeColumns(columns, ncols);
					return [self executionFailure:completion];
				}
				pcol->size = SQLClientStringBufferSizeForColumnType(pcol->type, dbcollen(self->connection, c));
				
					//Allocate memory in the current pcol struct for a buffer
					if ((pcol->buffer = calloc(1, pcol->size + 1)) == NULL)
					{
						SQLClientFreeColumns(columns, ncols);
						return [self executionFailure:completion];
					}
					
					//Bind column name
	                bindResult = dbbind(self->connection, c, NTBSTRINGBIND, pcol->size + 1, (BYTE*)pcol->buffer);
					if (bindResult == FAIL)
					{
						SQLClientFreeColumns(columns, ncols);
						return [self executionFailure:completion];
					}
					
					//Bind column status
	                bindResult = dbnullbind(self->connection, c, &pcol->status);
					if (bindResult == FAIL)
					{
						SQLClientFreeColumns(columns, ncols);
						return [self executionFailure:completion];
					}
				
				//printf("%s is type %d with value %s\n", pcol->name, pcol->type, pcol->buffer);
			}
			
			//printf("\n");
			
			//Loop through each row
            while ((row_code = dbnextrow(self->connection)) != NO_MORE_ROWS)
			{
				//Check row type
				switch (row_code)
				{
					//Regular row
					case REG_ROW:
					{
						//Create a new dictionary to contain the column names and vaues
						NSMutableDictionary* row = [[NSMutableDictionary alloc] initWithCapacity:ncols];
						
						//Loop through each column and create an entry where dictionary[columnName] = columnValue
						for (pcol = columns; pcol - columns < ncols; pcol++)
						{
							NSString* column = [NSString stringWithUTF8String:pcol->name];
							id value;
							if (pcol->status == -1) { //null value
								value = [NSNull null];
							} else {
								value = [NSString stringWithUTF8String:pcol->buffer];
							}
							//id value = [NSString stringWithUTF8String:pcol->buffer] ?: [NSNull null];
							row[column] = value;
                            //printf("%@=%@\n", column, value);
						}
                        
                        //Add an immutable copy to the table
						[table addObject:[row copy]];
						//printf("\n");
						break;
						}
						//Buffer full
						case BUF_FULL:
							SQLClientFreeColumns(columns, ncols);
							return [self executionFailure:completion];
						//Error
						case FAIL:
							SQLClientFreeColumns(columns, ncols);
							return [self executionFailure:completion];
						default:
							[self message:SQLClientRowIgnoreMessage];
					}
				}
				
				//Clean up
				SQLClientFreeColumns(columns, ncols);
			
			//Add immutable copy of table to output
			[output addObject:[table copy]];
		}
		
        //Success! Send an immutable copy of the results array
		[self executionSuccess:completion results:[output copy]];
	}];
}

- (void)disconnect
{
	if (connection != NULL) {
	    dbclose(connection);
		connection = NULL;
	}
}

#pragma mark - Private

//Invokes connection completion handler on callback queue with success = NO
- (void)connectionFailure:(void (^)(BOOL success))completion
{
    [[self effectiveCallbackQueue] addOperationWithBlock:^{
        if (completion)
            completion(NO);
    }];
    
    //Cleanup
    if (login != NULL) {
	    dbloginfree(login);
		login = NULL;
	}
	SQLClientFreeCString(&_password);
	SQLClientFreeCString(&_hostCString);
	SQLClientFreeCString(&_usernameCString);
	SQLClientFreeCString(&_databaseCString);
	SQLClientFreeCString(&_charsetCString);
}

//Invokes connection completion handler on callback queue with success = [self connected]
- (void)connectionSuccess:(void (^)(BOOL success))completion
{
    [[self effectiveCallbackQueue] addOperationWithBlock:^{
        if (completion)
            completion([self connected]);
    }];
    
    //Cleanup
    if (login != NULL) {
	    dbloginfree(login);
		login = NULL;
	}
	SQLClientFreeCString(&_password);
	SQLClientFreeCString(&_hostCString);
	SQLClientFreeCString(&_usernameCString);
	SQLClientFreeCString(&_databaseCString);
	SQLClientFreeCString(&_charsetCString);
}

//Invokes execution completion handler on callback queue with results = nil
- (void)executionFailure:(void (^)(NSArray* results))completion
{
    [[self effectiveCallbackQueue] addOperationWithBlock:^{
        if (completion)
            completion(nil);
    }];
    
    //Clean up
    dbfreebuf(connection);
}

//Invokes execution completion handler on callback queue with results array
- (void)executionSuccess:(void (^)(NSArray* results))completion results:(NSArray*)results
{
    [[self effectiveCallbackQueue] addOperationWithBlock:^{
        if (completion)
            completion(results);
    }];
    
    //Clean up
    dbfreebuf(connection);
}

- (NSOperationQueue *)effectiveCallbackQueue
{
	return self.callbackQueue ?: [NSOperationQueue mainQueue];
}

//Handles message callback from FreeTDS library.
int msg_handler(DBPROCESS* dbproc, DBINT msgno, int msgstate, int severity, char* msgtext, char* srvname, char* procname, int line)
{
	//Can't call self from a C function, so need to access singleton
	SQLClient* self = [SQLClient sharedInstance];
	[self message:[NSString stringWithUTF8String:msgtext]];
	return 0;
}

//Handles error callback from FreeTDS library.
int err_handler(DBPROCESS* dbproc, int severity, int dberr, int oserr, char* dberrstr, char* oserrstr)
{
	//Can't call self from a C function, so need to access singleton
	SQLClient* self = [SQLClient sharedInstance];
	[self error:[NSString stringWithUTF8String:dberrstr] code:dberr severity:severity];
	return INT_CANCEL;
}

//Forwards a message to the delegate on the callback queue if it implements
- (void)message:(NSString*)message
{
	//Invoke delegate on calling queue
	[self.callbackQueue addOperationWithBlock:^{
		if ([self.delegate respondsToSelector:@selector(message:)])
			[self.delegate message:message];
	}];
}

//Forwards an error message to the delegate on the callback queue.
- (void)error:(NSString*)error code:(int)code severity:(int)severity
{
	if (!self.delegate || ![self.delegate conformsToProtocol:@protocol(SQLClientDelegate)])
		[NSException raise:SQLClientDelegateError format:@""];
	
	//Invoke delegate on callback queue
	[self.callbackQueue addOperationWithBlock:^{
		[self.delegate error:error code:code severity:severity];
	}];
}

@end
