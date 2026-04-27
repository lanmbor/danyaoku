---
name: sap-successfactors
description: |
  SAP SuccessFactors integration. Connect to the SF OData API using OAuth2 SAML bearer authentication.
  Use when the user wants to interact with SAP SuccessFactors data, or provides SF credentials
  (apiServer, companyId, apiKey, userId, privateKey, certificate).
license: MIT
invoke: SFAPI
metadata:
  author: custom
  version: "2.0"
---

# SAP SuccessFactors

SAP SuccessFactors is a cloud-based human capital management (HCM) suite used by HR professionals
to manage employee performance, recruiting, learning, time off, compensation, and more.

Official docs: https://help.sap.com/docs/SAP_SUCCESSFACTORS

## Connection Setup

When the user provides credentials, collect these five values:

| Parameter | Description | Example |
|---|---|---|
| `apiServer` | SF API hostname (no https://) | `api2preview.sapsf.eu` |
| `companyId` | SF tenant/company ID | `Demo` |
| `apiKey` | OAuth2 client API Key from Admin Center | `OTdiZThmYz...` |
| `userId` | SF user ID to authenticate as | `123123` |
| `privateKey` | PEM private key (-----BEGIN PRIVATE KEY-----...) | file or pasted text |
| `certificate` | PEM certificate (-----BEGIN CERTIFICATE-----...) | file or pasted text |

### Certificate Requirements

SAP SuccessFactors requires a certificate with `digitalSignature` key usage. Generate one with:

```bash
openssl req -x509 -newkey rsa:2048 -keyout sf_private_key.pem -out sf_certificate.pem \
  -days 365 -nodes -subj "/CN=sap-sf-oauth" \
  -addext "keyUsage=critical,digitalSignature,nonRepudiation"
```

To copy the certificate as a single-line base64 for uploading to SF Admin Center:
```bash
openssl x509 -in sf_certificate.pem -outform DER | base64 -w 0 | clip
```

Upload this base64 value (no line breaks) to:
**SF Admin Center → OAuth2 Client Applications → [your client] → Certificate field**

### Authentication Method

SF uses OAuth2 with XML-signed SAML2 bearer assertions. The signing must use:
- Enveloped XML signature
- SHA-256 digest
- Exclusive C14N canonicalization (`http://www.w3.org/2001/10/xml-exc-c14n#`)

**Important:** Plain base64-encoded unsigned assertions will be rejected with 401.

### Python Helper Script

Once credentials are collected, create `sf_api.py` using this template:

```python
import base64, uuid, datetime, urllib.request, urllib.parse, ssl, json
from lxml import etree
from signxml import XMLSigner, methods

API_SERVER = "<apiServer>"
COMPANY_ID = "<companyId>"
API_KEY    = "<apiKey>"
USER_ID    = "<userId>"

with open("<path_to_private_key.pem>", "rb") as f:
    PRIVATE_KEY = f.read()
with open("<path_to_certificate.pem>", "rb") as f:
    CERTIFICATE = f.read()

_token_cache = {}

def get_token():
    now = datetime.datetime.now(datetime.UTC)
    if _token_cache.get("expires_at") and now < _token_cache["expires_at"]:
        return _token_cache["token"]

    token_url = f"https://{API_SERVER}/oauth/token"
    assertion_id = "_" + str(uuid.uuid4())
    not_after = now + datetime.timedelta(minutes=5)
    fmt = "%Y-%m-%dT%H:%M:%SZ"

    saml_xml = f"""<saml2:Assertion xmlns:saml2="urn:oasis:names:tc:SAML:2.0:assertion"
      ID="{assertion_id}" IssueInstant="{now.strftime(fmt)}" Version="2.0">
      <saml2:Issuer>{API_KEY}</saml2:Issuer>
      <saml2:Subject>
        <saml2:NameID Format="urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified">{USER_ID}</saml2:NameID>
        <saml2:SubjectConfirmation Method="urn:oasis:names:tc:SAML:2.0:cm:bearer">
          <saml2:SubjectConfirmationData NotOnOrAfter="{not_after.strftime(fmt)}" Recipient="{token_url}"/>
        </saml2:SubjectConfirmation>
      </saml2:Subject>
      <saml2:Conditions NotBefore="{now.strftime(fmt)}" NotOnOrAfter="{not_after.strftime(fmt)}">
        <saml2:AudienceRestriction><saml2:Audience>{token_url}</saml2:Audience></saml2:AudienceRestriction>
      </saml2:Conditions>
      <saml2:AuthnStatement AuthnInstant="{now.strftime(fmt)}">
        <saml2:AuthnContext>
          <saml2:AuthnContextClassRef>urn:oasis:names:tc:SAML:2.0:ac:classes:unspecified</saml2:AuthnContextClassRef>
        </saml2:AuthnContext>
      </saml2:AuthnStatement>
      <saml2:AttributeStatement>
        <saml2:Attribute Name="client_id">
          <saml2:AttributeValue xmlns:xs="http://www.w3.org/2001/XMLSchema"
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
            xsi:type="xs:string">{API_KEY}</saml2:AttributeValue>
        </saml2:Attribute>
      </saml2:AttributeStatement>
    </saml2:Assertion>"""

    root = etree.fromstring(saml_xml.encode())
    signer = XMLSigner(method=methods.enveloped, digest_algorithm="sha256",
                       c14n_algorithm="http://www.w3.org/2001/10/xml-exc-c14n#")
    signed_root = signer.sign(root, key=PRIVATE_KEY, cert=CERTIFICATE)
    encoded = base64.b64encode(etree.tostring(signed_root, xml_declaration=False)).decode()

    data = urllib.parse.urlencode({
        "grant_type": "urn:ietf:params:oauth:grant-type:saml2-bearer",
        "client_id": API_KEY,
        "company_id": COMPANY_ID,
        "assertion": encoded,
    }).encode()

    ctx = ssl.create_default_context()
    req = urllib.request.Request(token_url, data=data,
                                  headers={"Content-Type": "application/x-www-form-urlencoded"})
    with urllib.request.urlopen(req, context=ctx) as r:
        td = json.loads(r.read())
        _token_cache["token"] = td["access_token"]
        _token_cache["expires_at"] = now + datetime.timedelta(seconds=td.get("expires_in", 3600) - 60)
        return _token_cache["token"]

def sf_get(path, params=None):
    """Query the SF OData v2 API. Returns parsed JSON."""
    token = get_token()
    url = f"https://{API_SERVER}/odata/v2/{path}"
    if params:
        url += "?" + urllib.parse.urlencode(params)
    ctx = ssl.create_default_context()
    req = urllib.request.Request(url, headers={
        "Authorization": f"Bearer {token}",
        "Accept": "application/json"
    })
    with urllib.request.urlopen(req, context=ctx) as r:
        return json.loads(r.read())

def sf_get_metadata(entity):
    """Fetch OData metadata for a given entity."""
    token = get_token()
    url = f"https://{API_SERVER}/odata/v2/{entity}/$metadata"
    ctx = ssl.create_default_context()
    req = urllib.request.Request(url, headers={
        "Authorization": f"Bearer {token}",
        "Accept": "application/xml"
    })
    with urllib.request.urlopen(req, context=ctx) as r:
        return r.read().decode()
```

Install required dependencies:
```bash
pip install signxml lxml cryptography
```

### Verifying the connection

Test with a simple user query:
```python
result = sf_get("User", {"$top": "3", "$select": "userId,firstName,lastName,email"})
print(json.dumps(result, indent=2))
```

## Working with SF OData API

### Querying entities

```python
# List job requisitions
result = sf_get("JobRequisition", {
    "$top": "10",
    "$select": "jobReqId,jobCode,internalStatus,numberOpenings,jobStartDate",
    "$filter": "internalStatus eq 'Open'"
})

# Get a specific user
result = sf_get("User('8218182')", {"$select": "userId,firstName,lastName,email"})

# Get entity metadata (all fields/parameters)
meta = sf_get_metadata("JobRequisition")
```

### Common entities

| Entity | Description |
|---|---|
| `User` | Employee/user profiles |
| `JobRequisition` | Job requisitions (recruiting) |
| `JobApplication` | Candidate applications |
| `PerformanceReview` | Performance review forms |
| `Goal` | Employee goals |
| `TimeOff` | Time off requests |
| `EmpJob` | Employee job information |
| `EmpCompensation` | Compensation data |
| `Position` | Position management |
| `Org Chart` | Organizational structure |

### Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `401 Unable to verify signature` | Cert in SF doesn't match private key | Re-upload cert to SF Admin Center → OAuth2 Client Applications |
| `401 API key does not exist` | Wrong API key for this company | Check exact API Key value in SF Admin Center |
| `400 Invalid SAML assertion` | Assertion not XML-signed | Use `XMLSigner` with enveloped method + exclusive C14N |
| `400 COE_PROPERTY_NOT_FOUND` | Field not in this tenant's data model | Check available fields via `sf_get_metadata(entity)` |
| `fetch failed` (Membrane) | Network issue or wrong apiServer hostname | Verify apiServer is hostname only, no `https://` |
