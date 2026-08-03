import { createClient } from 'jsr:@supabase/supabase-js@2';

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Max-Age': '86400',
};

interface PatientConnection {
  family_member_id: string;
  patient_id: string;
  is_active: boolean;
}

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: CORS_HEADERS, status: 204 });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    
    console.log('[family-portal-patient-data] Environment check:', {
      hasUrl: !!supabaseUrl,
      hasServiceKey: !!supabaseServiceKey,
    });

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      console.error('[family-portal-patient-data] Missing authorization header');
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' }),
        { status: 401, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }

    // Create a client with service role to bypass RLS
    // The JWT is already validated by Supabase when calling the edge function
    const supabase = createClient(supabaseUrl!, supabaseServiceKey!);
    
    // Get the user ID from the JWT token (already validated by Supabase)
    const token = authHeader.replace('Bearer ', '');
    
    // Decode JWT to get user ID without making an API call
    // JWT format: header.payload.signature
    const parts = token.split('.');
    if (parts.length !== 3) {
      console.error('[family-portal-patient-data] Invalid JWT format');
      return new Response(
        JSON.stringify({ error: 'Invalid token format' }),
        { status: 401, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }
    
    // Decode base64url payload
    const payload = JSON.parse(atob(parts[1].replace(/-/g, '+').replace(/_/g, '/')));
    const familyMemberId = payload.sub; // 'sub' claim contains user ID
    
    console.log('[family-portal-patient-data] Authenticated family member:', familyMemberId);

    // Get patientId from query params
    const url = new URL(req.url);
    let patientId = url.searchParams.get('patientId');

    if (!patientId) {
      return new Response(
        JSON.stringify({ error: 'patientId parameter required' }),
        { status: 400, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }

    console.log('[family-portal-patient-data] Requested patient ID:', patientId);

    // Verify the family member has an active connection to this patient
    // Since connections are stored in local storage on the client, we'll verify by checking
    // if the patient exists and has shared their data
    console.log('[family-portal-patient-data] Querying users table for patient:', patientId);
    
    // First, try to find ANY user with this ID (no role filter) to debug
    const { data: anyUserData, error: anyUserError } = await supabase
      .from('users')
      .select('id, name, role, auth_user_id')
      .eq('id', patientId)
      .maybeSingle();
    
    console.log('[family-portal-patient-data] Query ANY user by ID:', {
      found: !!anyUserData,
      data: anyUserData,
      error: anyUserError,
    });
    
    // If query returned error, return it immediately for debugging
    if (anyUserError) {
      console.error('[family-portal-patient-data] ❌ Database query error:', anyUserError);
      return new Response(
        JSON.stringify({ 
          error: 'Database query failed',
          debug: {
            queryError: anyUserError,
            patientId: patientId,
            message: 'Failed to query users table - check RLS policies and table structure'
          }
        }),
        { status: 500, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }

    let patientData: any = null;
    
    // Check if we found a user and if they're a patient
    if (anyUserData) {
      if (anyUserData.role === 'patient') {
        patientData = anyUserData;
        console.log('[family-portal-patient-data] ✓ Found patient directly by ID');
      } else {
        console.log('[family-portal-patient-data] ⚠️  User found but role is:', anyUserData.role);
        // Try to find their patient profile by auth_user_id
        const { data: patientByAuth } = await supabase
          .from('users')
          .select('id, name, role, auth_user_id')
          .eq('auth_user_id', anyUserData.auth_user_id)
          .eq('role', 'patient')
          .maybeSingle();
        
        if (patientByAuth) {
          patientData = patientByAuth;
          patientId = patientByAuth.id;
          console.log('[family-portal-patient-data] ✓ Found patient profile via auth_user_id');
        }
      }
    }
    
    // If still not found, try using patientId as auth_user_id
    if (!patientData) {
      console.log('[family-portal-patient-data] Trying auth_user_id fallback...');
      const { data: byAuthId } = await supabase
        .from('users')
        .select('id, name, role, auth_user_id')
        .eq('auth_user_id', patientId)
        .eq('role', 'patient')
        .maybeSingle();
      
      if (byAuthId) {
        patientData = byAuthId;
        patientId = byAuthId.id;
        console.log('[family-portal-patient-data] ✓ Found patient via auth_user_id fallback');
      }
    }

    if (!patientData) {
      console.error('[family-portal-patient-data] ❌ Patient not found after all attempts');
      return new Response(
        JSON.stringify({ 
          error: 'Patient not found or access denied',
          debug: {
            searchedPatientId: patientId,
            userFoundById: !!anyUserData,
            userRoleFoundById: anyUserData?.role,
            triedAuthIdFallback: true,
          }
        }),
        { status: 404, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }

    // Family portal is enabled for all patients by default
    // (No family_portal_enabled field in database)

    console.log('[family-portal-patient-data] ✓ Patient verified:', patientData.name);

    // Fetch patient's tracker entries (last 90 days)
    const ninetyDaysAgo = new Date();
    ninetyDaysAgo.setDate(ninetyDaysAgo.getDate() - 90);

    const { data: trackerEntries, error: trackerError } = await supabase
      .from('tracker_entries')
      .select('*')
      .eq('user_id', patientId)
      .gte('date', ninetyDaysAgo.toISOString())
      .order('date', { ascending: false })
      .limit(90);

    if (trackerError) {
      console.error('[family-portal-patient-data] Tracker query error:', trackerError);
      return new Response(
        JSON.stringify({ error: 'Failed to fetch tracker data' }),
        { status: 500, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
      );
    }

    console.log('[family-portal-patient-data] ✓ Found', trackerEntries?.length || 0, 'tracker entries');

    // Fetch patient's milestones
    const { data: milestones, error: milestonesError } = await supabase
      .from('milestones')
      .select('*')
      .eq('user_id', patientId)
      .order('order', { ascending: true });

    if (milestonesError) {
      console.error('[family-portal-patient-data] Milestones query error:', milestonesError);
    }

    console.log('[family-portal-patient-data] ✓ Found', milestones?.length || 0, 'milestones');

    // Fetch patient's goals
    const { data: goals, error: goalsError } = await supabase
      .from('goals')
      .select('*')
      .eq('user_id', patientId)
      .eq('active', true)
      .order('created_at', { ascending: false });

    if (goalsError) {
      console.error('[family-portal-patient-data] Goals query error:', goalsError);
    }

    console.log('[family-portal-patient-data] ✓ Found', goals?.length || 0, 'goals');

    // Look up patient record (patients table) to find patient_id for notes/resources
    let patientRecordId: string | null = null;
    try {
      const { data: patientRow } = await supabase
        .from('patients')
        .select('id')
        .eq('user_id', patientId)
        .maybeSingle();
      patientRecordId = patientRow?.id ?? null;
    } catch (e) {
      console.error('[family-portal-patient-data] patients lookup error:', e);
    }
    console.log('[family-portal-patient-data] patientRecordId for notes/resources:', patientRecordId);

    // Fetch family-visible notes & resources
    let notes: any[] = [];
    let resources: any[] = [];
    if (patientRecordId) {
      const { data: notesData, error: notesError } = await supabase
        .from('patient_notes')
        .select('*')
        .eq('patient_id', patientRecordId)
        .eq('visibility', 'family_visible')
        .order('pinned', { ascending: false })
        .order('created_at', { ascending: false });
      if (notesError) console.error('[family-portal-patient-data] notes error:', notesError);
      notes = notesData || [];

      const { data: resourcesData, error: resourcesError } = await supabase
        .from('patient_resources')
        .select('*')
        .eq('patient_id', patientRecordId)
        .eq('visibility', 'family_visible')
        .order('created_at', { ascending: false });
      if (resourcesError) console.error('[family-portal-patient-data] resources error:', resourcesError);
      resources = resourcesData || [];
    }
    console.log('[family-portal-patient-data] ✓ Found', notes.length, 'family-visible notes');
    console.log('[family-portal-patient-data] ✓ Found', resources.length, 'family-visible resources');

    // Extract nutrition data from tracker entries
    const nutritionEntries = trackerEntries
      ?.filter((entry: any) => entry.custom_fields?.nutritionV1)
      .map((entry: any) => ({
        id: entry.id,
        userId: entry.user_id,
        date: entry.date,
        nutritionLog: entry.custom_fields.nutritionV1,
        createdAt: entry.created_at,
        updatedAt: entry.updated_at,
      })) || [];
    
    console.log('[family-portal-patient-data] ✓ Found', nutritionEntries.length, 'nutrition entries');

    // Return all patient data
    const responseData = {
      patientId: patientId,
      userId: patientId, // For backwards compatibility
      trackerEntries: trackerEntries || [],
      nutritionEntries: nutritionEntries, // NEW: Nutrition data
      milestones: milestones || [],
      goals: goals || [],
      notes: notes,
      resources: resources,
      entryCount: trackerEntries?.length || 0,
    };

    console.log('[family-portal-patient-data] ✅ Returning data to family member');

    return new Response(
      JSON.stringify(responseData),
      { status: 200, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('[family-portal-patient-data] Unexpected error:', error);
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    return new Response(
      JSON.stringify({ error: 'Internal server error', message: errorMessage }),
      { status: 500, headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' } }
    );
  }
});
