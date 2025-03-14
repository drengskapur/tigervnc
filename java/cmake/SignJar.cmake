if(NOT Java_PATH)
  message(FATAL_ERROR "Java_PATH must be defined")
endif()

if(NOT JAR_FILE)
  message(FATAL_ERROR "JAR_FILE must be defined")
endif()

set(KEYTOOL "${Java_PATH}/keytool")
set(JARSIGNER "${Java_PATH}/jarsigner")

if(JAVA_KEYSTORE)
  if((NOT JAVA_KEYSTORE_TYPE))
    message(FATAL_ERROR "When JAVA_KEYSTORE is specified, JAVA_KEYSTORE_TYPE must also be specified:\n${ERROR}")
  endif()
  string(TOUPPER "${JAVA_KEYSTORE_TYPE}" JAVA_KEYSTORE_TYPE_STRING)
  if(${JAVA_KEYSTORE_TYPE_STRING} MATCHES "PKCS11")
    if((NOT JAVA_PKCS11_PROVIDER_ARG) OR (NOT JAVA_STOREPASS) OR (NOT JAVA_KEY_ALIAS))
      message(FATAL_ERROR "When JAVA_KEYSTORE_TYPE is PKCS11, JAVA_STOREPASS, JAVA_PKCS11_PROVIDER_ARG, and JAVA_KEY_ALIAS must also be specified:\n${ERROR}")
    endif()
  elseif((${JAVA_KEYSTORE_TYPE_STRING} MATCHES "JKS") OR (${JAVA_KEYSTORE_TYPE_STRING} MATCHES "PKCS12"))
    if((NOT JAVA_STOREPASS) OR (NOT JAVA_KEYPASS) OR (NOT JAVA_KEY_ALIAS))
      message(FATAL_ERROR "When JAVA_KEYSTORE_TYPE is JKS or PKCS12, JAVA_STOREPASS, JAVA_KEYPASS, and JAVA_KEY_ALIAS must also be specified:\n${ERROR}")
    endif()
  else()
    message(FATAL_ERROR "Unsupported keystore type:\n${ERROR}")
  endif()
else()
  message(STATUS "Generating self-signed certificate")
  file(REMOVE tigervnc.keystore)
  execute_process(COMMAND
    ${KEYTOOL} -genkey -alias TigerVNC -keystore tigervnc.keystore -keyalg RSA
      -storepass tigervnc -keypass tigervnc -validity 7300
      -dname "CN=TigerVNC, OU=Software development, O=The TigerVNC project, L=Austin, S=Texas, C=US"
    RESULT_VARIABLE RESULT OUTPUT_VARIABLE OUTPUT ERROR_VARIABLE ERROR)
  if(NOT RESULT EQUAL 0)
    message(FATAL_ERROR "${KEYTOOL} failed:\n${ERROR}")
  endif()
  set(JAVA_KEYSTORE "tigervnc.keystore")
  set(JAVA_STOREPASS "tigervnc")
  set(JAVA_KEYPASS "tigervnc")
  set(JAVA_KEY_ALIAS "TigerVNC")
endif()

message(STATUS "Signing ${JAR_FILE}")

set(ARGS -keystore ${JAVA_KEYSTORE} -storetype ${JAVA_KEYSTORE_TYPE})

if(${JAVA_STOREPASS} MATCHES "^:env")
  string(REGEX REPLACE "^:env[\t ]+(.*)$" "\\1" JAVA_STOREPASS "${JAVA_STOREPASS}")
  set(ARGS ${ARGS} -storepass:env ${JAVA_STOREPASS})
elseif("${JAVA_STOREPASS}" MATCHES "^:file")
  string(REGEX REPLACE "^:file[\t ]+(.*)$" "\\1" JAVA_STOREPASS "${JAVA_STOREPASS}")
  set(ARGS ${ARGS} -storepass:file ${JAVA_STOREPASS})
else()
  set(ARGS ${ARGS} -storepass ${JAVA_STOREPASS})
endif()

if(${JAVA_KEYSTORE_TYPE_STRING} MATCHES "PKCS11")
  set(ARGS ${ARGS} -providerClass ${JAVA_PKCS11_PROVIDER_CLASS})
  set(ARGS ${ARGS} -providerArg ${JAVA_PKCS11_PROVIDER_ARG})
elseif((${JAVA_KEYSTORE_TYPE_STRING} MATCHES "JKS") OR (${JAVA_KEYSTORE_TYPE_STRING} MATCHES "PKCS12"))
  if(${JAVA_KEYPASS} MATCHES "^:env")
    string(REGEX REPLACE "^:env[\t ]+(.*)$" "\\1" JAVA_KEYPASS "${JAVA_KEYPASS}")
    set(ARGS ${ARGS} -keypass:env ${JAVA_KEYPASS})
  elseif("${JAVA_KEYPASS}" MATCHES "^:file")
    string(REGEX REPLACE "^:file[\t ]+(.*)$" "\\1" JAVA_KEYPASS "${JAVA_KEYPASS}")
    set(ARGS ${ARGS} -keypass:file ${JAVA_KEYPASS})
  else()
    set(ARGS ${ARGS} -keypass ${JAVA_KEYPASS})
  endif()
endif()

if(JAVA_CERT_CHAIN)
  set(ARGS ${ARGS} -certchain ${JAVA_CERT_CHAIN})
endif()

if(JAVA_TSA_URL)
  set(ARGS ${ARGS} -tsa ${JAVA_TSA_URL})
endif()

execute_process(COMMAND
  ${JARSIGNER} ${ARGS} ${JAR_FILE} ${JAVA_KEY_ALIAS}
  RESULT_VARIABLE RESULT OUTPUT_VARIABLE OUTPUT ERROR_VARIABLE ERROR)

if(NOT RESULT EQUAL 0)
  message(FATAL_ERROR "${JARSIGNER} failed:\n${ERROR}")
endif()

if(EXISTS tigervnc.keystore)
  file(REMOVE tigervnc.keystore)
endif()
