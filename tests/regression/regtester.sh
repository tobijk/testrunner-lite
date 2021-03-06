#!/bin/sh
set -x
TRLITEBIN=$1
INPUTXML=$2
TRLITEEXTRAFLAGS=$3
OUTPUTXML=/tmp/$(basename ${INPUTXML} .xml).out.xml
CASESIN=/tmp/trl_cases.in
CASESOUT=/tmp/trl_cases.out
STEPSIN=/tmp/trl_steps.in
STEPSOUT=/tmp/trl_steps.out
RESULT=0

check_case_results() {
    sed -nre 's/^[[:space:]]*<case.*name="([^"]+)".*>[[:space:]]*<!--.*result="([^"]+)".*-->[[:space:]]*$/\1 \2/p' ${INPUTXML} > ${CASESIN}
    sed -nre 's/^[[:space:]]*<case.*name="([^"]+)".*result="([^"]+)".*>[[:space:]]*$/\1 \2/p' ${OUTPUTXML} > ${CASESOUT}
    diff ${CASESIN} ${CASESOUT}
    if [ $? -ne 0 ]; then
	echo "Expected case results did not match for ${INPUTXML}" 1>&2
	RESULT=1
    fi
}

check_step_results() {
    sed -nre 's/^[[:space:]]*<step.*>(.+)<\/step>[[:space:]]*<!--.*result="([^"]+)".*-->[[:space:]]*$/\1 \2/p' ${INPUTXML} > ${STEPSIN}
    sed -nre 's/^[[:space:]]*<step.*command="([^"]+)".*result="([^"]+)".*>[[:space:]]*$/\1 \2/p' ${OUTPUTXML} > ${STEPSOUT}
    diff ${STEPSIN} ${STEPSOUT}
    if [ $? -ne 0 ]; then
	echo "Expected step results did not match for ${INPUTXML}" 1>&2
	RESULT=1
    fi
}

# Check that expected return value for testrunner-lite has been defined
EXPECTED_RETVAL=$(sed -nre 's/^[[:space:]]*<testdefinition.*>[[:space:]]*<!--.*result="([^"]+)".*-->[[:space:]]*$/\1/p' ${INPUTXML})
if [ -z "${EXPECTED_RETVAL}" ]; then
    echo "ERROR: Cannot find expected return value of testrunner-lite from $1" 1>&2
    exit 2
fi

echo "Running $(basename $0) with ${INPUTXML}"

# Run tests
echo "---- testrunner-lite output begins ----"
$TRLITEBIN -s -f ${INPUTXML} -o ${OUTPUTXML} -v ${TRLITEEXTRAFLAGS}
RETVAL=$?
echo "---- testrunner-lite output ends ----"

if [ ${RETVAL} -ne "${EXPECTED_RETVAL}" ]; then
    echo "ERROR: Expected return value ${EXPECTED_RETVAL} from testrunner-lite but $RETVAL was returned" 1>&2
    RESULT=1
fi

# Validate output file of testrunner-lite
if ! xmllint --noout --schema /usr/share/test-definition/testdefinition-results.xsd ${OUTPUTXML}
then
    echo "Output file ${OUTPUTXML} did not pass validation" 1>&2
    RESULT=1
fi

# Run checking functions
check_case_results
check_step_results

# Clean created files
#rm -f ${OUTPUTXML} ${CASESIN} ${CASESOUT} ${STEPSIN} ${STEPSOUT}

if [ "${RESULT}" -ne 0 ]; then
    echo "$(basename $0) with ${INPUTXML}: FAIL"
    exit 1
else
    echo "$(basename $0) with ${INPUTXML}: PASS"
fi
