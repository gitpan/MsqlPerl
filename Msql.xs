/* -*-C-*- */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "msql.h"

#ifndef IS_PRI_KEY
#define IS_PRI_KEY(a) IS_UNIQUE(a)
#endif

typedef int SysRet;
typedef m_result *Msql__Result;
typedef HV *Msql__Statement;
typedef HV *Msql;

#define dBSV				\
  HV *          hv;				\
  HV *          stash;				\
  SV *          rv;				\
  SV *          sv;				\
  SV *          svsock;				\
  SV *          svdb;				\
  SV *          svhost;				\
  char * 	name = "Msql::db_errstr"

#define dRESULT					\
  dBSV;					\
  Msql__Result	result = NULL;			\
  SV **		svp;				\
  char *	package = "Msql::Statement";	\
  int		sock

#define dFETCH		\
  dRESULT;			\
  int		off;		\
  m_field *	curField;	\
  m_row		cur

#define dQUERY		\
  HV *          hv;    	       	       	     \
  HV *          stash;			     \
  SV *          rv;			     \
  SV *          sv;			     \
  char *        name = "Msql::db_errstr";    \
  Msql__Result  result = NULL;		     \
  SV **         svp;			     \
  char *        package = "Msql::Statement"; \
  int           sock;			     \
  int           tmp = -1

#define ERRMSG				\
    sv = perl_get_sv(name,TRUE);	\
    sv_setpv(sv,msqlErrMsg);		\
    if (dowarn && ! SvTRUE(perl_get_sv("Msql::QUIET",TRUE))){ \
      warn("MSQL's message: %s", msqlErrMsg); \
    }					\
    XST_mUNDEF(0);			\
    XSRETURN(1);

#define readSOCKET				\
  if (svp = hv_fetch(handle,"SOCK",4,FALSE)){	\
    sock = SvIV(*svp);				\
    svsock = (SV*)newSVsv(*svp);		\
  } else {					\
    svsock = &sv_undef;		\
  }						\
  if (svp = hv_fetch(handle,"DATABASE",8,FALSE)){	\
    svdb = (SV*)newSVsv(*svp);	\
  } else {					\
    svdb = &sv_undef;		\
  }						\
  if (svp = hv_fetch(handle,"HOST",4,FALSE)){	\
    svhost = (SV*)newSVsv(*svp);	\
  } else {					\
    svhost = &sv_undef;		\
  }

#define readRESULT				\
  if (svp = hv_fetch(handle,"RESULT",6,FALSE)){	\
    sv = *svp;					\
    result = (Msql__Result)SvIV(sv);		\
  } else {					\
    sv =  &sv_undef;		\
  }

#define retMSQLSOCK				\
    rv = newRV((SV*)hv);			\
    stash = gv_stashpv(package, TRUE);		\
    ST(0) = sv_2mortal(sv_bless(rv, stash))

/* this is not the location where we leak! */
#define retMSQLRESULT						\
    hv_store(hv,"RESULT",6,(SV *)newSViv((IV)result),0);	\
    retMSQLSOCK

#define iniHV 	hv = (HV*)sv_2mortal((SV*)newHV())

#define iniAV 	av = (AV*)sv_2mortal((SV*)newAV())

#define MSQLPERL_FETCH_INTERNAL(a)	\
      iniAV;				\
      msqlFieldSeek(result,0);		\
      numfields = msqlNumFields(result);\
      while (off< numfields){		\
	curField = msqlFetchField(result);	\
	a				\
	off++;				\
      }					\
      RETVAL = newRV((SV*)av)

static int
not_here(s)
char *s;
{
    croak("Msql::%s not implemented on this architecture", s);
    return -1;
}

static double
constant(name, arg)
char *name;
int arg;
{
    errno = 0;
    switch (*name) {
    case 'C':
	if (strEQ(name, "CHAR_TYPE"))
#ifdef CHAR_TYPE
	    return CHAR_TYPE;
#else
	    goto not_there;
#endif
	break;
    case 'I':
	if (strEQ(name, "IDENT_TYPE"))
#ifdef IDENT_TYPE
	    return IDENT_TYPE;
#else
	    goto not_there;
#endif
	if (strEQ(name, "IDX_TYPE"))
#ifdef IDX_TYPE
	    return IDX_TYPE;
#else
	    goto not_there;
#endif
	if (strEQ(name, "INT_TYPE"))
#ifdef INT_TYPE
	    return INT_TYPE;
#else
	    goto not_there;
#endif
	break;
    case 'N':
	if (strEQ(name, "NOT_NULL_FLAG"))
#ifdef NOT_NULL_FLAG
	    return NOT_NULL_FLAG;
#else
	    goto not_there;
#endif
	if (strEQ(name, "NULL_TYPE"))
#ifdef NULL_TYPE
	    return NULL_TYPE;
#else
	    goto not_there;
#endif
	break;
    case 'P':
	if (strEQ(name, "PRI_KEY_FLAG"))
#ifdef PRI_KEY_FLAG
	    return PRI_KEY_FLAG;
#else
	    goto not_there;
#endif
	break;
    case 'R':
	if (strEQ(name, "REAL_TYPE"))
#ifdef REAL_TYPE
	    return REAL_TYPE;
#else
	    goto not_there;
#endif
	break;
    case 'S':
	if (strEQ(name, "SYSVAR_TYPE"))
#ifdef SYSVAR_TYPE
	    return SYSVAR_TYPE;
#else
	    goto not_there;
#endif
	break;
    case 'V':
	if (strEQ(name, "VARCHAR_TYPE"))
#ifdef VARCHAR_TYPE
	    return VARCHAR_TYPE;
#else
	    goto not_there;
#endif
	break;
    }
    errno = EINVAL;
    return 0;

not_there:
    errno = ENOENT;
    return 0;
}

MODULE = Statement	PACKAGE = Msql::Statement	PREFIX = msql

PROTOTYPES: ENABLE

SV *
fetchinternal(handle, key)
     Msql::Statement		handle
     char *	key
   PROTOTYPE: $$
   CODE:
{
  /* fetchinternal */
  dRESULT;
  AV*	av;
  int	off = 0;
  int	numfields;
  m_field *	curField;

  readRESULT;
  switch (*key){
  case 'I':
    if (strEQ(key, "ISNOTNULL")){
	MSQLPERL_FETCH_INTERNAL(av_push(av,(SV*)newSViv(IS_NOT_NULL(curField->flags))););
    }
    else if (strEQ(key, "ISPRIKEY")) {
	MSQLPERL_FETCH_INTERNAL(av_push(av,(SV*)newSViv(IS_PRI_KEY(curField->flags))););
    }
    break;
  case 'L':
    if (strEQ(key, "LENGTH")) {
	MSQLPERL_FETCH_INTERNAL(av_push(av,(SV*)newSViv(curField->length)););
    }
    break;
  case 'N':
    if (strEQ(key, "NAME")) {
	MSQLPERL_FETCH_INTERNAL(av_push(av,(SV*)newSVpv(curField->name,strlen(curField->name))););
    }
    else if (strEQ(key, "NUMFIELDS")){
      RETVAL = newSViv((IV)msqlNumFields(result));
    }
    else if (strEQ(key, "NUMROWS")){
      RETVAL = newSViv((IV)msqlNumRows(result));
    }
    break;
  case 'R':
    if (strEQ(key, "RESULT"))
      RETVAL = newSViv((IV)result);
    break;
  case 'T':
    if (strEQ(key, "TABLE")) {
	MSQLPERL_FETCH_INTERNAL(av_push(av,(SV*)newSVpv(curField->table,strlen(curField->table))););
    }
    else if (strEQ(key, "TYPE")) {
	MSQLPERL_FETCH_INTERNAL(av_push(av,(SV*)newSViv(curField->type)););
    }
    break;
  }
}
   OUTPUT:
     RETVAL

void
msqlfetchrow(handle)
   Msql::Statement	handle
   PROTOTYPE: $
   PPCODE:
{
/* This one is very simple, it just returns us an array of the fields
   of a row. If we want to know more about the fields, we look into
   $sth->{XXX}, where XXX may be one of NAME, TABLE, TYPE, IS_PRI_KEY,
   and IS_NOT_NULL */

  dFETCH;
  int		placeholder = 1;

  /* msqlFetchRow */
  readRESULT;
  if (result && (cur = msqlFetchRow(result))) {
    off = 0;
    msqlFieldSeek(result,0);
    if ( msqlNumFields(result) > 0 )
      placeholder = msqlNumFields(result);
    EXTEND(sp,placeholder);
    while(off < placeholder){
      curField = msqlFetchField(result);

      if (cur[off]){
	PUSHs(sv_2mortal((SV*)newSVpv(cur[off], strlen(cur[off]))));
      }else{
	PUSHs(&sv_undef);
      }

      off++;
    }
  }
}

void
msqlfetchhash(handle)
   Msql::Statement	handle
   PROTOTYPE: $
   PPCODE:
{

  dFETCH;
  int		placeholder = 1;

  /* msqlfetchhash */
  readRESULT;
  if (result && (cur = msqlFetchRow(result))) {
    off = 0;
    msqlFieldSeek(result,0);
    if ( msqlNumFields(result) > 0 )
      placeholder = msqlNumFields(result);
    EXTEND(sp,placeholder*2);
    while(off < placeholder){
      curField = msqlFetchField(result);

      PUSHs(sv_2mortal((SV*)newSVpv(curField->name,strlen(curField->name))));
      if (cur[off]){
	PUSHs(sv_2mortal((SV*)newSVpv(cur[off], strlen(cur[off]))));
      }else{
	PUSHs(&sv_undef);
      }

      off++;
    }
  }
}

void
msqldataseek(handle,pos)
   Msql::Statement	handle
   int			pos
   PROTOTYPE: $$
   CODE:
{
/* In my eyes, we don't need that, but as it's there we implement it,
   of course: set the position of the cursor to a specified record
   number. */

  Msql__Result	result = NULL;
  SV *		sv;
  SV **		svp;

  /* msqlDataSeek */
  readRESULT;
  if (result)
    msqlDataSeek(result,pos);
  else
    croak("Could not DataSeek, no result handle found");
}

void
msqlDESTROY(handle)
   Msql::Statement	handle
   PROTOTYPE: $
   CODE:
{
/* We have to free memory, when a handle is not used anymore */

  Msql__Result	result = NULL;
  SV *		sv;
  SV **		svp;

  /* msqlDESTROY */
  readRESULT;
  if (result){
/*    printf("Msql::Statement -- Going to free result: %lx\n", result); */
    msqlFreeResult(result);
/*    printf("Msql::Statement -- Result freed: %lx\n", result); */
  } else {
/*    printf("Msql.xs: Could not free some result\n"); */
  }
}

MODULE = Msql		PACKAGE = Msql		PREFIX = msql

double
constant(name,arg)
	char *		name
	int		arg

char *
msqlerrmsg(package = "Msql")
   PROTOTYPE:
   CODE:
   RETVAL = msqlErrMsg;
   OUTPUT:
   RETVAL

char *
msqlgethostinfo(package = "Msql")
     PROTOTYPE:
     CODE:
     RETVAL = msqlGetHostInfo();
     OUTPUT:
     RETVAL

char *
msqlgetserverinfo(package = "Msql")
     PROTOTYPE:
     CODE:
     RETVAL = msqlGetServerInfo();
     OUTPUT:
     RETVAL

int
msqlgetprotoinfo(package = "Msql")
     PROTOTYPE:
     CODE:
     RETVAL = msqlGetProtoInfo();
     OUTPUT:
     RETVAL

SysRet
msqlcreatedb(handle,db)
     Msql		handle
     char *	db
     PROTOTYPE: $$
     CODE:
     {
      dRESULT;
      readSOCKET;
      RETVAL = msqlCreateDB(sock,db);
      if (RETVAL == -1) {ERRMSG;}
     }
     OUTPUT:
     RETVAL

SysRet
msqldropdb(handle,db)
     Msql		handle
     char *	db
     PROTOTYPE: $$
     CODE:
     {
      dRESULT;
      readSOCKET;
      RETVAL = msqlDropDB(sock,db);
      if (RETVAL == -1) {ERRMSG;}
     }
     OUTPUT:
     RETVAL

SysRet
msqlshutdown(handle)
     Msql		handle
     PROTOTYPE: $
     CODE:
     {
      dRESULT;
      readSOCKET;
      RETVAL = msqlShutdown(sock);
      if (RETVAL == -1) {ERRMSG;}
     }
     OUTPUT:
     RETVAL

SysRet
msqlreloadacls(handle)
     Msql		handle
     PROTOTYPE: $
     CODE:
     {
      dRESULT;
      readSOCKET;
      RETVAL = msqlReloadAcls(sock);
      if (RETVAL == -1) {ERRMSG;}
     }
     OUTPUT:
     RETVAL

void
msqlconnect(package = "Msql",host=NULL,db=NULL)
     char *		package
     char *		host
     char *		db
   PROTOTYPE: $;$$
   CODE:
{
/* As we may have multiple simultaneous sessions with more than one
   connect, we bless an object, as soon as a connection is established
   by Msql->Connect(host, db). The object is a hash, where we put the
   socket returned by msqlConnect under the key "SOCK".  An extra
   argument may be given to select the database we are going to access
   with this handle. As soon as a database is selected, we add it to
   the hash table in the key DATABASE. */

  dBSV;
  int           sock;

  if (host && strlen(host)>0){
    sock = msqlConnect(host);
  } else {
    sock = msqlConnect(NULL);
  }

  if ((sock < 0) || (db && (msqlSelectDB(sock,db) < 0))) {
    ERRMSG;
  } else {
    iniHV;
    svsock = (SV*)newSViv(sock);
    if (db)
      svdb = (SV*)newSVpv(db,0);
    else
      svdb = &sv_undef;
    if (host)
      svhost = (SV*)newSVpv(host,0);
    else
      svhost = &sv_undef;
    hv_store(hv,"SOCK",4,svsock,0);
    hv_store(hv,"HOST",4,svhost,0);
    hv_store(hv,"DATABASE",8,svdb,0);
    retMSQLSOCK;
  }
}

SysRet
msqlselectdb(handle, db)
     Msql		handle
     char *		db
   PROTOTYPE: $$
   CODE:
{
/* This routine does not return an object, it just sets a database
   within the connection. */

  /* msqlSelectDB */
  dRESULT;

  readSOCKET;
  if (sock && db)
    RETVAL = msqlSelectDB(sock,db);
  else
    RETVAL = -1;
  if (RETVAL == -1){
    ERRMSG;
  } else {
    hv_store(handle,"DATABASE",8,(SV*)newSVpv(db,0),0);
  }
}
 OUTPUT:
RETVAL

void
msqlquery(handle, query)
   Msql		handle
     char *	query
   PROTOTYPE: $$
   CODE:
{
/* A successful query returns a statement handle in the
   Msql::Statement class. In that class we have a FetchRow() method,
   that returns us one row after the other. We may repeat the fetching
   of rows beginning with an arbitrary row number after we reset the
   position-pointer with DataSeek().
   */

  dQUERY;

  if (svp = hv_fetch(handle,"SOCK",4,FALSE))
    sock = SvIV(*svp);

  if (sock)
    tmp = msqlQuery(sock,query);
  if (tmp < 0 ) {
    ERRMSG;
  } else {
    hv = (HV*)sv_2mortal((SV*)newHV());
    if (result = msqlStoreResult()){
      hv_store(hv,"RESULT",6,(SV *)newSViv((IV)result),0);
      rv = newRV((SV*)hv);
      stash = gv_stashpv(package, TRUE);
      ST(0) = sv_2mortal(sv_bless(rv, stash));
    } else {
      ST(0) = sv_newmortal();
      sv_setnv( ST(0), 1);
    }
  }
}

void
msqllistdbs(handle)
   Msql		handle
   PROTOTYPE: $
   PPCODE:
{
/* We return an array, of course. */

  dFETCH;

  readSOCKET;
  if (sock)
    result = msqlListDBs(sock);
  if (result == NULL ) {
    ERRMSG;
  } else {
    while ( cur = msqlFetchRow(result) ){
      EXTEND(sp,1);
      curField = msqlFetchField(result);
      PUSHs(sv_2mortal((SV*)newSVpv(cur[0], strlen(cur[0]))));
    }
    msqlFreeResult(result);
  }
}

void
msqllisttables(handle)
   Msql		handle
   PROTOTYPE: $
   PPCODE:
{
/* We return an array, of course. */

  dFETCH;

  readSOCKET;
  if (sock)
    result = msqlListTables(sock);
  if (result == NULL ) {
    ERRMSG;
  } else {
    while ( cur = msqlFetchRow(result) ){
      EXTEND(sp,1);
      curField = msqlFetchField(result);
      PUSHs(sv_2mortal((SV*)newSVpv(cur[0], strlen(cur[0]))));
    }
    msqlFreeResult(result);
  }
}

void
msqllistfields(handle, table)
   Msql			handle
   char *		table
   PROTOTYPE: $$
   CODE:
{
/* This is similar to a query with 0 rows in the result. Unlike with
   the query we are guaranteed by the API to have field information
   where we also have it after a successful query. That means, we find
   no result with FetchRow, but we have a ref to a filled Hash with
   NAME, TABLE, TYPE, IS_PRI_KEY, and IS_NOT_NULL. We do bless into
   msqlStatement, so DESTROY will free the query. */

  dQUERY;

  if (svp = hv_fetch(handle,"SOCK",4,FALSE))
    sock = SvIV(*svp);
  if (sock && table)
    result = msqlListFields(sock,table);
  if (result == NULL ) {
    ERRMSG;
  } else {
    hv = (HV*)sv_2mortal((SV*)newHV());
    hv_store(hv,"RESULT",6,(SV *)newSViv((IV)result),0);
    rv = newRV((SV*)hv);
    stash = gv_stashpv(package, TRUE);
    ST(0) = sv_2mortal(sv_bless(rv, stash));
  }
}

void
msqlDESTROY(handle)
   Msql			handle
   PROTOTYPE: $
   CODE:
{
/* Somebody has freed the object that keeps us connected with the
   database, so we have to tell the server, that we are done. */

  SV **	svp;
  int	sock;

  if (svp = hv_fetch(handle,"SOCK",4,FALSE))
    sock = SvIV(*svp);
  if (sock)
    msqlClose(sock);
}
