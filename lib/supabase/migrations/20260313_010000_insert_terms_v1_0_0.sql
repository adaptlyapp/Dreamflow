-- Insert Terms & Conditions v1.0.0 with combined T&C and PHI Authorization
-- HIPAA-compliant consent document

-- First, deactivate any existing terms_and_conditions documents
UPDATE consent_documents 
SET is_active = false, updated_at = now()
WHERE document_type = 'terms_and_conditions';

-- Insert the new combined Terms & Conditions + PHI Authorization v1.0.0
INSERT INTO consent_documents (
  document_type,
  version,
  title,
  content,
  effective_date,
  is_active,
  created_at,
  updated_at
) VALUES (
  'terms_and_conditions',
  '1.0.0',
  'Terms & Conditions and PHI Authorization',
  'Privacy & Protected Health Information (PHI) Authorization

By selecting "I Agree", you authorize Adaptly to collect, create, receive, store, process, and analyze certain Protected Health Information (PHI) for the purpose of providing and improving your recovery management experience within the Adaptly platform.

PHI may include, but is not limited to:

Recovery milestones

Pain levels and symptom tracking

Treatment plans and therapy routines

Daily activity logs and wellness inputs

Health provider or caregiver information

Recovery goals and progress metrics

Communications submitted through the platform

Purpose of Data Use

Your PHI is used to:

• Build and maintain your personalized "Framework for Success" recovery plan
• Track progress and long-term recovery trends
• Generate data-driven insights about your recovery
• Improve Adaptly''s product features and user experience
• Facilitate collaboration with healthcare providers or caregivers you choose to connect

Adaptly does not sell your health data to advertisers or third parties.

Authorized Access

Access to your PHI is limited to:

Authorized Adaptly personnel who require access to operate and support the platform

Healthcare providers, caregivers, or collaborators that you explicitly authorize or connect

Service providers assisting with secure infrastructure, analytics, or support (under strict confidentiality and data protection agreements)

All such access is limited to what is reasonably necessary to provide the Adaptly service.

Security & Safeguards

Adaptly maintains administrative, technical, and physical safeguards designed to protect the confidentiality, integrity, and availability of your PHI. These safeguards may include:

Encryption of data in transit and at rest

Secure authentication systems

Access control and role-based permissions

System monitoring and audit logging

Secure infrastructure providers

While we strive to protect your information, no digital system can guarantee absolute security.

Revocation of Authorization

You may revoke this authorization at any time by contacting us at:

adaptlyapp@gmail.com

Upon revocation:

Adaptly will stop collecting new PHI from you

Existing data may still be retained where required for legal, compliance, or operational purposes

Revoking authorization may limit or disable certain features of the Adaptly platform.

Terms of Service
1. Informational Tool — Not Medical Advice

Adaptly is a recovery management and tracking tool, not a medical provider.

The information, analytics, and guidance provided through Adaptly:

are for informational and organizational purposes only

do not constitute medical advice

are not a substitute for professional medical care

Always consult your physician or licensed healthcare professional before making decisions related to your health, treatment, or recovery program.

2. User Responsibilities

By using Adaptly, you agree to:

Provide accurate and truthful information

Use the platform responsibly and in accordance with applicable laws

Not misuse the service or attempt to disrupt platform operations

You agree not to upload false medical data, impersonate healthcare professionals, or attempt to access another user''s data.

3. Account Security

You are responsible for maintaining the confidentiality of your account credentials.

We recommend:

Using a strong and unique password

Enabling biometric authentication where available

Logging out from shared devices

You are responsible for all activity that occurs under your account.

4. Data Portability & User Rights

Consistent with modern privacy standards and healthcare data practices, you may request:

A digital copy of your recovery data

Correction of inaccurate information

Deletion of your account (subject to legal retention requirements)

Requests may be submitted to:

adaptlyapp@gmail.com

5. Data Retention

Adaptly may retain user data and PHI for a reasonable period necessary to:

Provide the service

Maintain system integrity

Comply with legal or regulatory obligations

Resolve disputes or enforce agreements

Data may be securely deleted or anonymized when no longer required.

6. Platform Availability

Adaptly strives to maintain reliable service but does not guarantee uninterrupted availability.

Temporary outages may occur due to:

maintenance

technical issues

infrastructure disruptions

updates or improvements

7. Limitation of Liability

To the maximum extent permitted by law:

Adaptly and its operators shall not be liable for any indirect, incidental, consequential, or special damages arising from use of the platform.

This includes but is not limited to:

health decisions made based on platform insights

interruptions in service

loss of data

Users remain responsible for consulting qualified healthcare professionals regarding medical decisions.

8. Modifications to the Terms

Adaptly may update these Terms and Privacy Authorization periodically.

When updates occur:

the version number and effective date will change

users may be required to review and re-accept the updated terms

Continued use of the platform after updates indicates acceptance of the revised terms.

9. Termination of Use

Adaptly reserves the right to suspend or terminate accounts that:

violate these Terms

attempt to misuse the platform

threaten the security of other users or the system

Users may also delete their account at any time.

10. Governing Law

These Terms shall be governed by the laws of the United States and the State of Washington, without regard to conflict of law principles.

Consent Acknowledgment

By selecting "I Agree", you confirm that:

• You have read and understood these Terms
• You authorize Adaptly to process your PHI as described above
• You agree to the Terms of Service and Privacy Authorization

Your acceptance will be electronically recorded along with the terms version, timestamp, and system metadata for compliance and auditing purposes.',
  now(),
  true,
  now(),
  now()
);

-- Add comment for documentation
COMMENT ON TABLE consent_documents IS 'HIPAA-compliant consent documents with version tracking. Current active version: Terms & Conditions v1.0.0 (combined T&C + PHI Authorization)';
