# Scan one-line retained exchange files without one shell process per request.
# The request is the prefix before the sorted `response` key; response text is
# never checked as if it were an acquisition payload.
BEGIN {
    if (kind != "decision" && kind != "embedding") exit 2
    decision_count = split("problem_statement hints_text instance_id fail_to_pass pass_to_pass gold", decision_markers, " ")
    embedding_count = split("problem_statement hints_text FAIL_TO_PASS PASS_TO_PASS", embedding_markers, " ")
}

function fail(reason) {
    print "FAIL " FILENAME " " reason
    bad = 1
}

{
    if (FNR != 1) {
        fail("is not a one-line exchange")
        next
    }
    response = index($0, "\",\"response\":\"")
    if (response == 0) {
        fail("has no response boundary")
        next
    }
    payload = substr($0, 1, response - 1)
    if (kind == "decision") {
        if (index(payload, "ATTUNE_FAMILIES_STATE_V1\\\\nobjective: family-formation\\\\n") == 0)
            fail("is not a families state")
        lower = tolower(payload)
        for (i = 1; i <= decision_count; i++)
            if (index(lower, decision_markers[i]) != 0) fail("names " decision_markers[i])
        # An issue field is forbidden, but source paths like SignatureIssue.tsx
        # are admitted repository facts and must not trip the law. The request
        # is JSON escaped once inside the retained exchange envelope.
        if (index(lower, "\\\"issue\\\":") != 0)
            fail("names issue field")
    } else {
        if (index(payload, "\"protocol\":\"attune-families-embeddings-v1\"") == 0 ||
            index(payload, "\\\"encoding_format\\\":\\\"base64\\\"") == 0)
            fail("is not a families document batch")
        for (i = 1; i <= embedding_count; i++)
            if (index(payload, embedding_markers[i]) != 0) fail("names " embedding_markers[i])
    }
}

END {
    if (bad) exit 1
}
