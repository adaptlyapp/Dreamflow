export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.1"
  }
  public: {
    Tables: {
      account_requests: {
        Row: {
          created_at: string | null
          department: string | null
          email: string
          full_name: string
          id: string
          portal: string
          reason: string | null
          review_notes: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          role: string
          status: string
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          department?: string | null
          email: string
          full_name: string
          id?: string
          portal: string
          reason?: string | null
          review_notes?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          role: string
          status?: string
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          department?: string | null
          email?: string
          full_name?: string
          id?: string
          portal?: string
          reason?: string | null
          review_notes?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          role?: string
          status?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "account_requests_reviewed_by_fkey"
            columns: ["reviewed_by"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
        ]
      }
      achievements: {
        Row: {
          category: string
          condition: string | null
          created_at: string | null
          description: string
          icon: string
          id: string
          requirement: number
          tier: number
          title: string
        }
        Insert: {
          category: string
          condition?: string | null
          created_at?: string | null
          description: string
          icon: string
          id?: string
          requirement: number
          tier: number
          title: string
        }
        Update: {
          category?: string
          condition?: string | null
          created_at?: string | null
          description?: string
          icon?: string
          id?: string
          requirement?: number
          tier?: number
          title?: string
        }
        Relationships: []
      }
      audit_logs: {
        Row: {
          action: string
          actor_id: string | null
          actor_name: string | null
          created_at: string | null
          details: Json | null
          entity_id: string | null
          entity_type: string
          facility_id: string | null
          hospital_id: string | null
          id: string
          ip_address: string | null
          organization_id: string | null
        }
        Insert: {
          action: string
          actor_id?: string | null
          actor_name?: string | null
          created_at?: string | null
          details?: Json | null
          entity_id?: string | null
          entity_type: string
          facility_id?: string | null
          hospital_id?: string | null
          id?: string
          ip_address?: string | null
          organization_id?: string | null
        }
        Update: {
          action?: string
          actor_id?: string | null
          actor_name?: string | null
          created_at?: string | null
          details?: Json | null
          entity_id?: string | null
          entity_type?: string
          facility_id?: string | null
          hospital_id?: string | null
          id?: string
          ip_address?: string | null
          organization_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "audit_logs_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "audit_logs_facility_id_fkey"
            columns: ["facility_id"]
            isOneToOne: false
            referencedRelation: "facilities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "audit_logs_hospital_id_fkey"
            columns: ["hospital_id"]
            isOneToOne: false
            referencedRelation: "hospitals"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "audit_logs_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      blog_email_sends: {
        Row: {
          id: string
          post_id: string | null
          sent_at: string | null
          sent_by: string | null
          subscriber_count: number | null
        }
        Insert: {
          id?: string
          post_id?: string | null
          sent_at?: string | null
          sent_by?: string | null
          subscriber_count?: number | null
        }
        Update: {
          id?: string
          post_id?: string | null
          sent_at?: string | null
          sent_by?: string | null
          subscriber_count?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "blog_email_sends_post_id_fkey"
            columns: ["post_id"]
            isOneToOne: false
            referencedRelation: "blog_posts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "blog_email_sends_sent_by_fkey"
            columns: ["sent_by"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
        ]
      }
      blog_posts: {
        Row: {
          author_id: string | null
          author_name: string
          category: string
          content: string
          cover_image_url: string | null
          created_at: string | null
          excerpt: string | null
          id: string
          published_at: string | null
          slug: string
          status: string
          tags: string[] | null
          title: string
          updated_at: string | null
        }
        Insert: {
          author_id?: string | null
          author_name?: string
          category?: string
          content: string
          cover_image_url?: string | null
          created_at?: string | null
          excerpt?: string | null
          id?: string
          published_at?: string | null
          slug: string
          status?: string
          tags?: string[] | null
          title: string
          updated_at?: string | null
        }
        Update: {
          author_id?: string | null
          author_name?: string
          category?: string
          content?: string
          cover_image_url?: string | null
          created_at?: string | null
          excerpt?: string | null
          id?: string
          published_at?: string | null
          slug?: string
          status?: string
          tags?: string[] | null
          title?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "blog_posts_author_id_fkey"
            columns: ["author_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
        ]
      }
      blog_subscribers: {
        Row: {
          email: string
          id: string
          name: string | null
          status: string
          subscribed_at: string | null
          unsubscribed_at: string | null
        }
        Insert: {
          email: string
          id?: string
          name?: string | null
          status?: string
          subscribed_at?: string | null
          unsubscribed_at?: string | null
        }
        Update: {
          email?: string
          id?: string
          name?: string | null
          status?: string
          subscribed_at?: string | null
          unsubscribed_at?: string | null
        }
        Relationships: []
      }
      blueprint_collaborators: {
        Row: {
          added_at: string
          added_by: string | null
          blueprint_id: string
          role: string
          user_id: string
        }
        Insert: {
          added_at?: string
          added_by?: string | null
          blueprint_id: string
          role?: string
          user_id: string
        }
        Update: {
          added_at?: string
          added_by?: string | null
          blueprint_id?: string
          role?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "blueprint_collaborators_blueprint_id_fkey"
            columns: ["blueprint_id"]
            isOneToOne: false
            referencedRelation: "recovery_blueprints"
            referencedColumns: ["id"]
          },
        ]
      }
      care_plan_modules: {
        Row: {
          attachments: Json | null
          care_plan_id: string | null
          created_at: string | null
          description: string | null
          duration_minutes: number | null
          frequency: string | null
          id: string
          instructions: string | null
          order_index: number
          title: string
          type: string
          updated_at: string | null
        }
        Insert: {
          attachments?: Json | null
          care_plan_id?: string | null
          created_at?: string | null
          description?: string | null
          duration_minutes?: number | null
          frequency?: string | null
          id?: string
          instructions?: string | null
          order_index?: number
          title: string
          type: string
          updated_at?: string | null
        }
        Update: {
          attachments?: Json | null
          care_plan_id?: string | null
          created_at?: string | null
          description?: string | null
          duration_minutes?: number | null
          frequency?: string | null
          id?: string
          instructions?: string | null
          order_index?: number
          title?: string
          type?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "care_plan_modules_care_plan_id_fkey"
            columns: ["care_plan_id"]
            isOneToOne: false
            referencedRelation: "care_plans"
            referencedColumns: ["id"]
          },
        ]
      }
      care_plans: {
        Row: {
          condition: string | null
          created_at: string | null
          created_by: string | null
          description: string | null
          duration_weeks: number | null
          facility_id: string | null
          hospital_id: string | null
          id: string
          name: string
          organization_id: string | null
          published_at: string | null
          status: string
          updated_at: string | null
        }
        Insert: {
          condition?: string | null
          created_at?: string | null
          created_by?: string | null
          description?: string | null
          duration_weeks?: number | null
          facility_id?: string | null
          hospital_id?: string | null
          id?: string
          name: string
          organization_id?: string | null
          published_at?: string | null
          status?: string
          updated_at?: string | null
        }
        Update: {
          condition?: string | null
          created_at?: string | null
          created_by?: string | null
          description?: string | null
          duration_weeks?: number | null
          facility_id?: string | null
          hospital_id?: string | null
          id?: string
          name?: string
          organization_id?: string | null
          published_at?: string | null
          status?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "care_plans_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "care_plans_facility_id_fkey"
            columns: ["facility_id"]
            isOneToOne: false
            referencedRelation: "facilities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "care_plans_hospital_id_fkey"
            columns: ["hospital_id"]
            isOneToOne: false
            referencedRelation: "hospitals"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "care_plans_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      client_approvals: {
        Row: {
          access_code: string | null
          contact_name: string
          created_at: string | null
          email: string
          hospital_name: string
          id: string
          notes: string | null
          phone: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          status: string | null
        }
        Insert: {
          access_code?: string | null
          contact_name: string
          created_at?: string | null
          email: string
          hospital_name: string
          id?: string
          notes?: string | null
          phone?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: string | null
        }
        Update: {
          access_code?: string | null
          contact_name?: string
          created_at?: string | null
          email?: string
          hospital_name?: string
          id?: string
          notes?: string | null
          phone?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "client_approvals_reviewed_by_fkey"
            columns: ["reviewed_by"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
        ]
      }
      clinical_assessments: {
        Row: {
          ais_grade: string | null
          assessment_date: string
          assessment_type: string
          created_at: string | null
          deep_anal_pressure: boolean | null
          examiner_id: string
          id: string
          lems_left: number | null
          lems_right: number | null
          motor_details: Json | null
          motor_score_left: number | null
          motor_score_right: number | null
          neurological_level: string | null
          notes: string | null
          patient_id: string
          sensory_details: Json | null
          sensory_light_touch_left: number | null
          sensory_light_touch_right: number | null
          sensory_pin_prick_left: number | null
          sensory_pin_prick_right: number | null
          uems_left: number | null
          uems_right: number | null
          updated_at: string | null
          voluntary_anal_contraction: boolean | null
          zpp_motor_left: string | null
          zpp_motor_right: string | null
          zpp_sensory_left: string | null
          zpp_sensory_right: string | null
        }
        Insert: {
          ais_grade?: string | null
          assessment_date?: string
          assessment_type?: string
          created_at?: string | null
          deep_anal_pressure?: boolean | null
          examiner_id: string
          id?: string
          lems_left?: number | null
          lems_right?: number | null
          motor_details?: Json | null
          motor_score_left?: number | null
          motor_score_right?: number | null
          neurological_level?: string | null
          notes?: string | null
          patient_id: string
          sensory_details?: Json | null
          sensory_light_touch_left?: number | null
          sensory_light_touch_right?: number | null
          sensory_pin_prick_left?: number | null
          sensory_pin_prick_right?: number | null
          uems_left?: number | null
          uems_right?: number | null
          updated_at?: string | null
          voluntary_anal_contraction?: boolean | null
          zpp_motor_left?: string | null
          zpp_motor_right?: string | null
          zpp_sensory_left?: string | null
          zpp_sensory_right?: string | null
        }
        Update: {
          ais_grade?: string | null
          assessment_date?: string
          assessment_type?: string
          created_at?: string | null
          deep_anal_pressure?: boolean | null
          examiner_id?: string
          id?: string
          lems_left?: number | null
          lems_right?: number | null
          motor_details?: Json | null
          motor_score_left?: number | null
          motor_score_right?: number | null
          neurological_level?: string | null
          notes?: string | null
          patient_id?: string
          sensory_details?: Json | null
          sensory_light_touch_left?: number | null
          sensory_light_touch_right?: number | null
          sensory_pin_prick_left?: number | null
          sensory_pin_prick_right?: number | null
          uems_left?: number | null
          uems_right?: number | null
          updated_at?: string | null
          voluntary_anal_contraction?: boolean | null
          zpp_motor_left?: string | null
          zpp_motor_right?: string | null
          zpp_sensory_left?: string | null
          zpp_sensory_right?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "clinical_assessments_examiner_id_fkey"
            columns: ["examiner_id"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "clinical_assessments_patient_id_fkey"
            columns: ["patient_id"]
            isOneToOne: false
            referencedRelation: "patients"
            referencedColumns: ["id"]
          },
        ]
      }
      comments: {
        Row: {
          author_id: string | null
          author_image_url: string | null
          author_name: string
          content: string
          created_at: string | null
          id: string
          post_id: string | null
          updated_at: string | null
        }
        Insert: {
          author_id?: string | null
          author_image_url?: string | null
          author_name: string
          content: string
          created_at?: string | null
          id?: string
          post_id?: string | null
          updated_at?: string | null
        }
        Update: {
          author_id?: string | null
          author_image_url?: string | null
          author_name?: string
          content?: string
          created_at?: string | null
          id?: string
          post_id?: string | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "comments_author_id_fkey"
            columns: ["author_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "comments_post_id_fkey"
            columns: ["post_id"]
            isOneToOne: false
            referencedRelation: "posts"
            referencedColumns: ["id"]
          },
        ]
      }
      communities: {
        Row: {
          created_at: string | null
          description: string
          id: string
          image_url: string | null
          member_count: number | null
          name: string
          owner_id: string | null
          owner_name: string | null
          privacy: string | null
          related_condition: string | null
          type: string
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          description: string
          id?: string
          image_url?: string | null
          member_count?: number | null
          name: string
          owner_id?: string | null
          owner_name?: string | null
          privacy?: string | null
          related_condition?: string | null
          type: string
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          description?: string
          id?: string
          image_url?: string | null
          member_count?: number | null
          name?: string
          owner_id?: string | null
          owner_name?: string | null
          privacy?: string | null
          related_condition?: string | null
          type?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "groups_owner_id_fkey"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      community_members: {
        Row: {
          community_id: string | null
          display_name: string | null
          id: string
          joined_at: string | null
          role: string | null
          status: string | null
          user_id: string | null
        }
        Insert: {
          community_id?: string | null
          display_name?: string | null
          id?: string
          joined_at?: string | null
          role?: string | null
          status?: string | null
          user_id?: string | null
        }
        Update: {
          community_id?: string | null
          display_name?: string | null
          id?: string
          joined_at?: string | null
          role?: string | null
          status?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "group_members_group_id_fkey"
            columns: ["community_id"]
            isOneToOne: false
            referencedRelation: "communities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "group_members_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      conditions: {
        Row: {
          ai_generated: boolean | null
          created_at: string | null
          daily_adjustments: string[] | null
          description: string
          id: string
          name: string
          related_groups: string[] | null
          resources: string[] | null
          symptoms: string[] | null
          timeline: Json | null
          updated_at: string | null
        }
        Insert: {
          ai_generated?: boolean | null
          created_at?: string | null
          daily_adjustments?: string[] | null
          description: string
          id?: string
          name: string
          related_groups?: string[] | null
          resources?: string[] | null
          symptoms?: string[] | null
          timeline?: Json | null
          updated_at?: string | null
        }
        Update: {
          ai_generated?: boolean | null
          created_at?: string | null
          daily_adjustments?: string[] | null
          description?: string
          id?: string
          name?: string
          related_groups?: string[] | null
          resources?: string[] | null
          symptoms?: string[] | null
          timeline?: Json | null
          updated_at?: string | null
        }
        Relationships: []
      }
      consent_documents: {
        Row: {
          content: string
          created_at: string | null
          document_type: string
          effective_date: string
          id: string
          is_active: boolean | null
          title: string
          updated_at: string | null
          version: string
        }
        Insert: {
          content: string
          created_at?: string | null
          document_type: string
          effective_date: string
          id?: string
          is_active?: boolean | null
          title: string
          updated_at?: string | null
          version: string
        }
        Update: {
          content?: string
          created_at?: string | null
          document_type?: string
          effective_date?: string
          id?: string
          is_active?: boolean | null
          title?: string
          updated_at?: string | null
          version?: string
        }
        Relationships: []
      }
      contacts: {
        Row: {
          created_at: string | null
          created_by: string | null
          email: string | null
          id: string
          lead_id: string
          name: string
          notes: string | null
          phone: string | null
          position: string | null
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          created_by?: string | null
          email?: string | null
          id?: string
          lead_id: string
          name: string
          notes?: string | null
          phone?: string | null
          position?: string | null
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          created_by?: string | null
          email?: string | null
          id?: string
          lead_id?: string
          name?: string
          notes?: string | null
          phone?: string | null
          position?: string | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "contacts_lead_id_fkey"
            columns: ["lead_id"]
            isOneToOne: false
            referencedRelation: "crm_leads"
            referencedColumns: ["id"]
          },
        ]
      }
      crm_activities: {
        Row: {
          completed: boolean | null
          contact_id: string | null
          created_at: string | null
          deal_id: string | null
          description: string | null
          due_date: string | null
          id: string
          organization_id: string
          subject: string | null
          type: string
          updated_at: string | null
        }
        Insert: {
          completed?: boolean | null
          contact_id?: string | null
          created_at?: string | null
          deal_id?: string | null
          description?: string | null
          due_date?: string | null
          id?: string
          organization_id: string
          subject?: string | null
          type: string
          updated_at?: string | null
        }
        Update: {
          completed?: boolean | null
          contact_id?: string | null
          created_at?: string | null
          deal_id?: string | null
          description?: string | null
          due_date?: string | null
          id?: string
          organization_id?: string
          subject?: string | null
          type?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "crm_activities_contact_id_fkey"
            columns: ["contact_id"]
            isOneToOne: false
            referencedRelation: "crm_contacts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "crm_activities_deal_id_fkey"
            columns: ["deal_id"]
            isOneToOne: false
            referencedRelation: "crm_deals"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "crm_activities_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      crm_contacts: {
        Row: {
          company: string | null
          created_at: string | null
          email: string | null
          id: string
          name: string
          notes: string | null
          organization_id: string
          phone: string | null
          position: string | null
          status: string | null
          updated_at: string | null
        }
        Insert: {
          company?: string | null
          created_at?: string | null
          email?: string | null
          id?: string
          name: string
          notes?: string | null
          organization_id: string
          phone?: string | null
          position?: string | null
          status?: string | null
          updated_at?: string | null
        }
        Update: {
          company?: string | null
          created_at?: string | null
          email?: string | null
          id?: string
          name?: string
          notes?: string | null
          organization_id?: string
          phone?: string | null
          position?: string | null
          status?: string | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "crm_contacts_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      crm_deals: {
        Row: {
          contact_id: string | null
          created_at: string | null
          expected_close_date: string | null
          id: string
          name: string
          notes: string | null
          organization_id: string
          probability: number | null
          stage: string | null
          updated_at: string | null
          value: number | null
        }
        Insert: {
          contact_id?: string | null
          created_at?: string | null
          expected_close_date?: string | null
          id?: string
          name: string
          notes?: string | null
          organization_id: string
          probability?: number | null
          stage?: string | null
          updated_at?: string | null
          value?: number | null
        }
        Update: {
          contact_id?: string | null
          created_at?: string | null
          expected_close_date?: string | null
          id?: string
          name?: string
          notes?: string | null
          organization_id?: string
          probability?: number | null
          stage?: string | null
          updated_at?: string | null
          value?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "crm_deals_contact_id_fkey"
            columns: ["contact_id"]
            isOneToOne: false
            referencedRelation: "crm_contacts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "crm_deals_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      crm_leads: {
        Row: {
          assigned_to: string | null
          billing_start_date: string | null
          company_name: string
          contact_name: string
          contact_role: string | null
          contract_signed_date: string | null
          created_at: string | null
          created_by: string | null
          decision_timeline: string | null
          demo_date: string | null
          demo_feedback: string | null
          demo_outcome: string | null
          demo_type: string | null
          email: string | null
          estimated_deal_size: number | null
          final_contract_value: number | null
          hospital_account_created: boolean | null
          id: string
          loss_notes: string | null
          loss_reason: string | null
          notes: string | null
          org_type: string | null
          phone: string | null
          pricing_model: string | null
          proposal_scope: string | null
          proposed_price: number | null
          source: string | null
          stage: string | null
          status: string | null
          updated_at: string | null
          use_case: string | null
        }
        Insert: {
          assigned_to?: string | null
          billing_start_date?: string | null
          company_name: string
          contact_name: string
          contact_role?: string | null
          contract_signed_date?: string | null
          created_at?: string | null
          created_by?: string | null
          decision_timeline?: string | null
          demo_date?: string | null
          demo_feedback?: string | null
          demo_outcome?: string | null
          demo_type?: string | null
          email?: string | null
          estimated_deal_size?: number | null
          final_contract_value?: number | null
          hospital_account_created?: boolean | null
          id?: string
          loss_notes?: string | null
          loss_reason?: string | null
          notes?: string | null
          org_type?: string | null
          phone?: string | null
          pricing_model?: string | null
          proposal_scope?: string | null
          proposed_price?: number | null
          source?: string | null
          stage?: string | null
          status?: string | null
          updated_at?: string | null
          use_case?: string | null
        }
        Update: {
          assigned_to?: string | null
          billing_start_date?: string | null
          company_name?: string
          contact_name?: string
          contact_role?: string | null
          contract_signed_date?: string | null
          created_at?: string | null
          created_by?: string | null
          decision_timeline?: string | null
          demo_date?: string | null
          demo_feedback?: string | null
          demo_outcome?: string | null
          demo_type?: string | null
          email?: string | null
          estimated_deal_size?: number | null
          final_contract_value?: number | null
          hospital_account_created?: boolean | null
          id?: string
          loss_notes?: string | null
          loss_reason?: string | null
          notes?: string | null
          org_type?: string | null
          phone?: string | null
          pricing_model?: string | null
          proposal_scope?: string | null
          proposed_price?: number | null
          source?: string | null
          stage?: string | null
          status?: string | null
          updated_at?: string | null
          use_case?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "crm_leads_assigned_to_fkey"
            columns: ["assigned_to"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "crm_leads_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
        ]
      }
      employees: {
        Row: {
          auth_user_id: string | null
          avatar_url: string | null
          created_at: string | null
          department: string | null
          email: string
          full_name: string
          hire_date: string | null
          id: string
          organization_id: string | null
          phone: string | null
          role: string
          status: string
          updated_at: string | null
        }
        Insert: {
          auth_user_id?: string | null
          avatar_url?: string | null
          created_at?: string | null
          department?: string | null
          email: string
          full_name: string
          hire_date?: string | null
          id?: string
          organization_id?: string | null
          phone?: string | null
          role: string
          status?: string
          updated_at?: string | null
        }
        Update: {
          auth_user_id?: string | null
          avatar_url?: string | null
          created_at?: string | null
          department?: string | null
          email?: string
          full_name?: string
          hire_date?: string | null
          id?: string
          organization_id?: string | null
          phone?: string | null
          role?: string
          status?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "employees_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      ems_notebooks: {
        Row: {
          color: string
          created_at: string
          created_by: string
          icon: string | null
          id: string
          name: string
          updated_at: string
        }
        Insert: {
          color?: string
          created_at?: string
          created_by: string
          icon?: string | null
          id?: string
          name: string
          updated_at?: string
        }
        Update: {
          color?: string
          created_at?: string
          created_by?: string
          icon?: string | null
          id?: string
          name?: string
          updated_at?: string
        }
        Relationships: []
      }
      ems_pages: {
        Row: {
          content: string | null
          created_at: string
          created_by: string
          id: string
          is_private: boolean
          order_index: number
          pinned: boolean
          section_id: string
          title: string
          updated_at: string
        }
        Insert: {
          content?: string | null
          created_at?: string
          created_by: string
          id?: string
          is_private?: boolean
          order_index?: number
          pinned?: boolean
          section_id: string
          title?: string
          updated_at?: string
        }
        Update: {
          content?: string | null
          created_at?: string
          created_by?: string
          id?: string
          is_private?: boolean
          order_index?: number
          pinned?: boolean
          section_id?: string
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "ems_pages_section_id_fkey"
            columns: ["section_id"]
            isOneToOne: false
            referencedRelation: "ems_sections"
            referencedColumns: ["id"]
          },
        ]
      }
      ems_sections: {
        Row: {
          color: string
          created_at: string
          created_by: string
          id: string
          name: string
          notebook_id: string
          order_index: number
          updated_at: string
        }
        Insert: {
          color?: string
          created_at?: string
          created_by: string
          id?: string
          name: string
          notebook_id: string
          order_index?: number
          updated_at?: string
        }
        Update: {
          color?: string
          created_at?: string
          created_by?: string
          id?: string
          name?: string
          notebook_id?: string
          order_index?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "ems_sections_notebook_id_fkey"
            columns: ["notebook_id"]
            isOneToOne: false
            referencedRelation: "ems_notebooks"
            referencedColumns: ["id"]
          },
        ]
      }
      facilities: {
        Row: {
          address: string | null
          city: string | null
          created_at: string | null
          id: string
          metro: string | null
          name: string
          organization_id: string
          settings: Json | null
          state: string | null
          status: string
          type: string
          updated_at: string | null
          zip: string | null
        }
        Insert: {
          address?: string | null
          city?: string | null
          created_at?: string | null
          id?: string
          metro?: string | null
          name: string
          organization_id: string
          settings?: Json | null
          state?: string | null
          status?: string
          type?: string
          updated_at?: string | null
          zip?: string | null
        }
        Update: {
          address?: string | null
          city?: string | null
          created_at?: string | null
          id?: string
          metro?: string | null
          name?: string
          organization_id?: string
          settings?: Json | null
          state?: string | null
          status?: string
          type?: string
          updated_at?: string | null
          zip?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "facilities_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      family_members: {
        Row: {
          auth_user_id: string | null
          created_at: string
          email: string
          id: string
          name: string
          nickname: string | null
          updated_at: string
        }
        Insert: {
          auth_user_id?: string | null
          created_at?: string
          email: string
          id?: string
          name: string
          nickname?: string | null
          updated_at?: string
        }
        Update: {
          auth_user_id?: string | null
          created_at?: string
          email?: string
          id?: string
          name?: string
          nickname?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      family_patient_links: {
        Row: {
          created_at: string | null
          family_member_id: string
          id: string
          patient_id: string
          patient_name: string
          relationship: string | null
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          family_member_id: string
          id?: string
          patient_id: string
          patient_name: string
          relationship?: string | null
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          family_member_id?: string
          id?: string
          patient_id?: string
          patient_name?: string
          relationship?: string | null
          updated_at?: string | null
        }
        Relationships: []
      }
      family_schedule_entries: {
        Row: {
          active: boolean
          caregiver: string | null
          category: string
          color: string
          created_at: string
          created_by: string
          created_by_name: string | null
          days_of_week: number[] | null
          duration_minutes: number
          id: string
          notes: string | null
          patient_id: string
          recurrence: string
          start_hour: number
          start_minute: number
          supplies: string[] | null
          title: string
          updated_at: string
        }
        Insert: {
          active?: boolean
          caregiver?: string | null
          category?: string
          color?: string
          created_at?: string
          created_by: string
          created_by_name?: string | null
          days_of_week?: number[] | null
          duration_minutes?: number
          id?: string
          notes?: string | null
          patient_id: string
          recurrence?: string
          start_hour?: number
          start_minute?: number
          supplies?: string[] | null
          title: string
          updated_at?: string
        }
        Update: {
          active?: boolean
          caregiver?: string | null
          category?: string
          color?: string
          created_at?: string
          created_by?: string
          created_by_name?: string | null
          days_of_week?: number[] | null
          duration_minutes?: number
          id?: string
          notes?: string | null
          patient_id?: string
          recurrence?: string
          start_hour?: number
          start_minute?: number
          supplies?: string[] | null
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "family_schedule_entries_patient_id_fkey"
            columns: ["patient_id"]
            isOneToOne: false
            referencedRelation: "patients"
            referencedColumns: ["id"]
          },
        ]
      }
      files: {
        Row: {
          created_at: string | null
          file_path: string
          file_size: number | null
          folder: string | null
          id: string
          mime_type: string | null
          name: string
          shared_with: string[] | null
          uploaded_by: string | null
        }
        Insert: {
          created_at?: string | null
          file_path: string
          file_size?: number | null
          folder?: string | null
          id?: string
          mime_type?: string | null
          name: string
          shared_with?: string[] | null
          uploaded_by?: string | null
        }
        Update: {
          created_at?: string | null
          file_path?: string
          file_size?: number | null
          folder?: string | null
          id?: string
          mime_type?: string | null
          name?: string
          shared_with?: string[] | null
          uploaded_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "files_uploaded_by_fkey"
            columns: ["uploaded_by"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
        ]
      }
      goals: {
        Row: {
          active: boolean | null
          created_at: string | null
          description: string | null
          id: string
          last_reset_at: string | null
          linked_tracker_key: string | null
          period: string
          profile_id: string | null
          progress_this_period: number | null
          target_per_period: number
          title: string
          updated_at: string | null
          user_id: string | null
        }
        Insert: {
          active?: boolean | null
          created_at?: string | null
          description?: string | null
          id?: string
          last_reset_at?: string | null
          linked_tracker_key?: string | null
          period: string
          profile_id?: string | null
          progress_this_period?: number | null
          target_per_period: number
          title: string
          updated_at?: string | null
          user_id?: string | null
        }
        Update: {
          active?: boolean | null
          created_at?: string | null
          description?: string | null
          id?: string
          last_reset_at?: string | null
          linked_tracker_key?: string | null
          period?: string
          profile_id?: string | null
          progress_this_period?: number | null
          target_per_period?: number
          title?: string
          updated_at?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "goals_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      grocery_list: {
        Row: {
          added_by: string | null
          added_by_name: string
          category: string
          checked: boolean
          created_at: string
          emoji: string | null
          id: string
          name: string
          notes: string | null
          patient_id: string
          updated_at: string
        }
        Insert: {
          added_by?: string | null
          added_by_name?: string
          category?: string
          checked?: boolean
          created_at?: string
          emoji?: string | null
          id?: string
          name: string
          notes?: string | null
          patient_id: string
          updated_at?: string
        }
        Update: {
          added_by?: string | null
          added_by_name?: string
          category?: string
          checked?: boolean
          created_at?: string
          emoji?: string | null
          id?: string
          name?: string
          notes?: string | null
          patient_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "grocery_list_added_by_fkey"
            columns: ["added_by"]
            isOneToOne: false
            referencedRelation: "family_members"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "grocery_list_patient_id_fkey"
            columns: ["patient_id"]
            isOneToOne: false
            referencedRelation: "patients"
            referencedColumns: ["id"]
          },
        ]
      }
      group_members: {
        Row: {
          group_id: string | null
          id: string
          joined_at: string | null
          status: string | null
          user_id: string | null
        }
        Insert: {
          group_id?: string | null
          id?: string
          joined_at?: string | null
          status?: string | null
          user_id?: string | null
        }
        Update: {
          group_id?: string | null
          id?: string
          joined_at?: string | null
          status?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "group_members_group_id_fkey1"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "group_members_user_id_fkey1"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      groups: {
        Row: {
          created_at: string | null
          description: string
          id: string
          image_url: string | null
          member_count: number | null
          name: string
          owner_id: string | null
          owner_name: string | null
          privacy: string | null
          related_condition: string | null
          type: string
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          description: string
          id?: string
          image_url?: string | null
          member_count?: number | null
          name: string
          owner_id?: string | null
          owner_name?: string | null
          privacy?: string | null
          related_condition?: string | null
          type: string
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          description?: string
          id?: string
          image_url?: string | null
          member_count?: number | null
          name?: string
          owner_id?: string | null
          owner_name?: string | null
          privacy?: string | null
          related_condition?: string | null
          type?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "groups_owner_id_fkey1"
            columns: ["owner_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      hospitals: {
        Row: {
          access_code: string | null
          brand_primary: number | null
          brand_secondary: number | null
          brand_tertiary: number | null
          city: string | null
          created_at: string | null
          id: string
          metro: string | null
          name: string
          updated_at: string | null
        }
        Insert: {
          access_code?: string | null
          brand_primary?: number | null
          brand_secondary?: number | null
          brand_tertiary?: number | null
          city?: string | null
          created_at?: string | null
          id?: string
          metro?: string | null
          name: string
          updated_at?: string | null
        }
        Update: {
          access_code?: string | null
          brand_primary?: number | null
          brand_secondary?: number | null
          brand_tertiary?: number | null
          city?: string | null
          created_at?: string | null
          id?: string
          metro?: string | null
          name?: string
          updated_at?: string | null
        }
        Relationships: []
      }
      icd10_codes: {
        Row: {
          category: string | null
          code: string
          created_at: string
          description: string
          id: string
          search_vec: unknown
        }
        Insert: {
          category?: string | null
          code: string
          created_at?: string
          description: string
          id?: string
          search_vec?: unknown
        }
        Update: {
          category?: string | null
          code?: string
          created_at?: string
          description?: string
          id?: string
          search_vec?: unknown
        }
        Relationships: []
      }
      integration_sync_logs: {
        Row: {
          created_at: string
          error_message: string | null
          event_type: string
          external_id: string | null
          id: string
          integration_id: string
          organization_id: string
          patient_id: string | null
          payload: Json
          status: string
          summary: string | null
        }
        Insert: {
          created_at?: string
          error_message?: string | null
          event_type: string
          external_id?: string | null
          id?: string
          integration_id: string
          organization_id: string
          patient_id?: string | null
          payload?: Json
          status?: string
          summary?: string | null
        }
        Update: {
          created_at?: string
          error_message?: string | null
          event_type?: string
          external_id?: string | null
          id?: string
          integration_id?: string
          organization_id?: string
          patient_id?: string | null
          payload?: Json
          status?: string
          summary?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "integration_sync_logs_integration_id_fkey"
            columns: ["integration_id"]
            isOneToOne: false
            referencedRelation: "integrations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "integration_sync_logs_patient_id_fkey"
            columns: ["patient_id"]
            isOneToOne: false
            referencedRelation: "patients"
            referencedColumns: ["id"]
          },
        ]
      }
      integrations: {
        Row: {
          api_url: string | null
          client_id: string | null
          client_secret: string | null
          created_at: string
          id: string
          last_synced_at: string | null
          name: string
          organization_id: string
          permissions: Json
          settings: Json
          status: string
          type: string
          updated_at: string
        }
        Insert: {
          api_url?: string | null
          client_id?: string | null
          client_secret?: string | null
          created_at?: string
          id?: string
          last_synced_at?: string | null
          name: string
          organization_id: string
          permissions?: Json
          settings?: Json
          status?: string
          type: string
          updated_at?: string
        }
        Update: {
          api_url?: string | null
          client_id?: string | null
          client_secret?: string | null
          created_at?: string
          id?: string
          last_synced_at?: string | null
          name?: string
          organization_id?: string
          permissions?: Json
          settings?: Json
          status?: string
          type?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "integrations_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      journey_goals: {
        Row: {
          completed_at: string | null
          created_at: string | null
          current_value: number | null
          description: string | null
          id: string
          milestone_id: string
          order: number | null
          started_at: string | null
          status: string
          target_value: number | null
          title: string
          unit: string | null
          updated_at: string | null
          user_id: string
        }
        Insert: {
          completed_at?: string | null
          created_at?: string | null
          current_value?: number | null
          description?: string | null
          id?: string
          milestone_id: string
          order?: number | null
          started_at?: string | null
          status?: string
          target_value?: number | null
          title: string
          unit?: string | null
          updated_at?: string | null
          user_id: string
        }
        Update: {
          completed_at?: string | null
          created_at?: string | null
          current_value?: number | null
          description?: string | null
          id?: string
          milestone_id?: string
          order?: number | null
          started_at?: string | null
          status?: string
          target_value?: number | null
          title?: string
          unit?: string | null
          updated_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "journey_goals_milestone_id_fkey"
            columns: ["milestone_id"]
            isOneToOne: false
            referencedRelation: "journey_milestones"
            referencedColumns: ["id"]
          },
        ]
      }
      journey_milestones: {
        Row: {
          completed_at: string | null
          created_at: string | null
          description: string | null
          due_date: string | null
          education_content: string | null
          id: string
          order: number | null
          phase_id: string
          priority: string | null
          started_at: string | null
          status: string
          title: string
          updated_at: string | null
          user_id: string
        }
        Insert: {
          completed_at?: string | null
          created_at?: string | null
          description?: string | null
          due_date?: string | null
          education_content?: string | null
          id?: string
          order?: number | null
          phase_id: string
          priority?: string | null
          started_at?: string | null
          status?: string
          title: string
          updated_at?: string | null
          user_id: string
        }
        Update: {
          completed_at?: string | null
          created_at?: string | null
          description?: string | null
          due_date?: string | null
          education_content?: string | null
          id?: string
          order?: number | null
          phase_id?: string
          priority?: string | null
          started_at?: string | null
          status?: string
          title?: string
          updated_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "journey_milestones_phase_id_fkey"
            columns: ["phase_id"]
            isOneToOne: false
            referencedRelation: "phases"
            referencedColumns: ["id"]
          },
        ]
      }
      journey_tasks: {
        Row: {
          assigned_to: string | null
          completed: boolean | null
          completed_at: string | null
          created_at: string | null
          description: string | null
          due_date: string | null
          goal_id: string
          id: string
          order: number | null
          title: string
          updated_at: string | null
          user_id: string
        }
        Insert: {
          assigned_to?: string | null
          completed?: boolean | null
          completed_at?: string | null
          created_at?: string | null
          description?: string | null
          due_date?: string | null
          goal_id: string
          id?: string
          order?: number | null
          title: string
          updated_at?: string | null
          user_id: string
        }
        Update: {
          assigned_to?: string | null
          completed?: boolean | null
          completed_at?: string | null
          created_at?: string | null
          description?: string | null
          due_date?: string | null
          goal_id?: string
          id?: string
          order?: number | null
          title?: string
          updated_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "journey_tasks_goal_id_fkey"
            columns: ["goal_id"]
            isOneToOne: false
            referencedRelation: "journey_goals"
            referencedColumns: ["id"]
          },
        ]
      }
      journeys: {
        Row: {
          completed_at: string | null
          condition_id: string
          created_at: string | null
          description: string | null
          domain_type: string
          id: string
          order: number | null
          started_at: string | null
          status: string
          title: string
          updated_at: string | null
          user_id: string
        }
        Insert: {
          completed_at?: string | null
          condition_id: string
          created_at?: string | null
          description?: string | null
          domain_type: string
          id?: string
          order?: number | null
          started_at?: string | null
          status?: string
          title: string
          updated_at?: string | null
          user_id: string
        }
        Update: {
          completed_at?: string | null
          condition_id?: string
          created_at?: string | null
          description?: string | null
          domain_type?: string
          id?: string
          order?: number | null
          started_at?: string | null
          status?: string
          title?: string
          updated_at?: string | null
          user_id?: string
        }
        Relationships: []
      }
      messages: {
        Row: {
          content: string
          created_at: string | null
          id: string
          is_read: boolean | null
          receiver_id: string | null
          receiver_image_url: string | null
          receiver_name: string
          sender_id: string | null
          sender_image_url: string | null
          sender_name: string
        }
        Insert: {
          content: string
          created_at?: string | null
          id?: string
          is_read?: boolean | null
          receiver_id?: string | null
          receiver_image_url?: string | null
          receiver_name: string
          sender_id?: string | null
          sender_image_url?: string | null
          sender_name: string
        }
        Update: {
          content?: string
          created_at?: string | null
          id?: string
          is_read?: boolean | null
          receiver_id?: string | null
          receiver_image_url?: string | null
          receiver_name?: string
          sender_id?: string | null
          sender_image_url?: string | null
          sender_name?: string
        }
        Relationships: [
          {
            foreignKeyName: "messages_receiver_id_fkey"
            columns: ["receiver_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "messages_sender_id_fkey"
            columns: ["sender_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      mfa_codes: {
        Row: {
          attempts: number | null
          code: string
          created_at: string | null
          email: string
          expires_at: string
          id: string
          max_attempts: number | null
          verified: boolean | null
        }
        Insert: {
          attempts?: number | null
          code: string
          created_at?: string | null
          email: string
          expires_at: string
          id?: string
          max_attempts?: number | null
          verified?: boolean | null
        }
        Update: {
          attempts?: number | null
          code?: string
          created_at?: string | null
          email?: string
          expires_at?: string
          id?: string
          max_attempts?: number | null
          verified?: boolean | null
        }
        Relationships: []
      }
      milestones: {
        Row: {
          completed: boolean | null
          condition_id: string | null
          created_at: string | null
          description: string | null
          due_date: string | null
          help_type: string | null
          id: string
          order: number | null
          profile_id: string | null
          title: string
          updated_at: string | null
          user_id: string | null
        }
        Insert: {
          completed?: boolean | null
          condition_id?: string | null
          created_at?: string | null
          description?: string | null
          due_date?: string | null
          help_type?: string | null
          id?: string
          order?: number | null
          profile_id?: string | null
          title: string
          updated_at?: string | null
          user_id?: string | null
        }
        Update: {
          completed?: boolean | null
          condition_id?: string | null
          created_at?: string | null
          description?: string | null
          due_date?: string | null
          help_type?: string | null
          id?: string
          order?: number | null
          profile_id?: string | null
          title?: string
          updated_at?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "milestones_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      organization_users: {
        Row: {
          created_at: string | null
          id: string
          organization_id: string
          role: string
          staff_id: string
        }
        Insert: {
          created_at?: string | null
          id?: string
          organization_id: string
          role: string
          staff_id: string
        }
        Update: {
          created_at?: string | null
          id?: string
          organization_id?: string
          role?: string
          staff_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "organization_users_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "organization_users_staff_id_fkey"
            columns: ["staff_id"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
        ]
      }
      organizations: {
        Row: {
          created_at: string | null
          id: string
          name: string
          settings: Json | null
          slug: string
          status: string
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          name: string
          settings?: Json | null
          slug: string
          status?: string
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          name?: string
          settings?: Json | null
          slug?: string
          status?: string
          updated_at?: string | null
        }
        Relationships: []
      }
      patient_care_plans: {
        Row: {
          assigned_by: string | null
          care_plan_id: string | null
          completed_at: string | null
          created_at: string | null
          id: string
          notes: string | null
          patient_id: string | null
          started_at: string | null
          status: string
          updated_at: string | null
        }
        Insert: {
          assigned_by?: string | null
          care_plan_id?: string | null
          completed_at?: string | null
          created_at?: string | null
          id?: string
          notes?: string | null
          patient_id?: string | null
          started_at?: string | null
          status?: string
          updated_at?: string | null
        }
        Update: {
          assigned_by?: string | null
          care_plan_id?: string | null
          completed_at?: string | null
          created_at?: string | null
          id?: string
          notes?: string | null
          patient_id?: string | null
          started_at?: string | null
          status?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "patient_care_plans_assigned_by_fkey"
            columns: ["assigned_by"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "patient_care_plans_care_plan_id_fkey"
            columns: ["care_plan_id"]
            isOneToOne: false
            referencedRelation: "care_plans"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "patient_care_plans_patient_id_fkey"
            columns: ["patient_id"]
            isOneToOne: false
            referencedRelation: "patients"
            referencedColumns: ["id"]
          },
        ]
      }
      patient_diagnoses: {
        Row: {
          added_by: string | null
          created_at: string
          icd10_code: string
          id: string
          notes: string | null
          onset_date: string | null
          patient_id: string
          resolved_date: string | null
          status: string
          updated_at: string
        }
        Insert: {
          added_by?: string | null
          created_at?: string
          icd10_code: string
          id?: string
          notes?: string | null
          onset_date?: string | null
          patient_id: string
          resolved_date?: string | null
          status?: string
          updated_at?: string
        }
        Update: {
          added_by?: string | null
          created_at?: string
          icd10_code?: string
          id?: string
          notes?: string | null
          onset_date?: string | null
          patient_id?: string
          resolved_date?: string | null
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "patient_diagnoses_added_by_fkey"
            columns: ["added_by"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "patient_diagnoses_icd10_code_fkey"
            columns: ["icd10_code"]
            isOneToOne: false
            referencedRelation: "icd10_codes"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "patient_diagnoses_patient_id_fkey"
            columns: ["patient_id"]
            isOneToOne: false
            referencedRelation: "patients"
            referencedColumns: ["id"]
          },
        ]
      }
      patient_external_ids: {
        Row: {
          created_at: string
          external_id: string
          external_mrn: string | null
          id: string
          integration_id: string
          metadata: Json
          patient_id: string
        }
        Insert: {
          created_at?: string
          external_id: string
          external_mrn?: string | null
          id?: string
          integration_id: string
          metadata?: Json
          patient_id: string
        }
        Update: {
          created_at?: string
          external_id?: string
          external_mrn?: string | null
          id?: string
          integration_id?: string
          metadata?: Json
          patient_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "patient_external_ids_integration_id_fkey"
            columns: ["integration_id"]
            isOneToOne: false
            referencedRelation: "integrations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "patient_external_ids_patient_id_fkey"
            columns: ["patient_id"]
            isOneToOne: false
            referencedRelation: "patients"
            referencedColumns: ["id"]
          },
        ]
      }
      patient_notes: {
        Row: {
          author_id: string
          body: string
          created_at: string | null
          id: string
          note_type: string
          patient_id: string
          pinned: boolean
          title: string
          updated_at: string | null
          visibility: string
        }
        Insert: {
          author_id: string
          body: string
          created_at?: string | null
          id?: string
          note_type?: string
          patient_id: string
          pinned?: boolean
          title: string
          updated_at?: string | null
          visibility?: string
        }
        Update: {
          author_id?: string
          body?: string
          created_at?: string | null
          id?: string
          note_type?: string
          patient_id?: string
          pinned?: boolean
          title?: string
          updated_at?: string | null
          visibility?: string
        }
        Relationships: [
          {
            foreignKeyName: "patient_notes_author_id_fkey"
            columns: ["author_id"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "patient_notes_patient_id_fkey"
            columns: ["patient_id"]
            isOneToOne: false
            referencedRelation: "patients"
            referencedColumns: ["id"]
          },
        ]
      }
      patient_resources: {
        Row: {
          blob_pathname: string | null
          created_at: string | null
          description: string | null
          external_url: string | null
          file_size: number | null
          id: string
          mime_type: string | null
          patient_id: string
          title: string
          type: string
          updated_at: string | null
          uploaded_by: string
          visibility: string
        }
        Insert: {
          blob_pathname?: string | null
          created_at?: string | null
          description?: string | null
          external_url?: string | null
          file_size?: number | null
          id?: string
          mime_type?: string | null
          patient_id: string
          title: string
          type: string
          updated_at?: string | null
          uploaded_by: string
          visibility?: string
        }
        Update: {
          blob_pathname?: string | null
          created_at?: string | null
          description?: string | null
          external_url?: string | null
          file_size?: number | null
          id?: string
          mime_type?: string | null
          patient_id?: string
          title?: string
          type?: string
          updated_at?: string | null
          uploaded_by?: string
          visibility?: string
        }
        Relationships: [
          {
            foreignKeyName: "patient_resources_patient_id_fkey"
            columns: ["patient_id"]
            isOneToOne: false
            referencedRelation: "patients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "patient_resources_uploaded_by_fkey"
            columns: ["uploaded_by"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
        ]
      }
      patient_staff: {
        Row: {
          created_at: string | null
          id: string
          patient_id: string | null
          role: string
          staff_id: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          patient_id?: string | null
          role: string
          staff_id?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          patient_id?: string | null
          role?: string
          staff_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "patient_staff_patient_id_fkey"
            columns: ["patient_id"]
            isOneToOne: false
            referencedRelation: "patients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "patient_staff_staff_id_fkey"
            columns: ["staff_id"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
        ]
      }
      patients: {
        Row: {
          access_code: string | null
          access_code_expires_at: string | null
          created_at: string | null
          created_by: string | null
          date_of_birth: string | null
          email: string | null
          facility_id: string | null
          hospital_id: string | null
          id: string
          mrn: string | null
          name: string
          organization_id: string | null
          phone: string | null
          status: string
          updated_at: string | null
          user_id: string | null
        }
        Insert: {
          access_code?: string | null
          access_code_expires_at?: string | null
          created_at?: string | null
          created_by?: string | null
          date_of_birth?: string | null
          email?: string | null
          facility_id?: string | null
          hospital_id?: string | null
          id?: string
          mrn?: string | null
          name: string
          organization_id?: string | null
          phone?: string | null
          status?: string
          updated_at?: string | null
          user_id?: string | null
        }
        Update: {
          access_code?: string | null
          access_code_expires_at?: string | null
          created_at?: string | null
          created_by?: string | null
          date_of_birth?: string | null
          email?: string | null
          facility_id?: string | null
          hospital_id?: string | null
          id?: string
          mrn?: string | null
          name?: string
          organization_id?: string | null
          phone?: string | null
          status?: string
          updated_at?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "patients_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "patients_facility_id_fkey"
            columns: ["facility_id"]
            isOneToOne: false
            referencedRelation: "facilities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "patients_hospital_id_fkey"
            columns: ["hospital_id"]
            isOneToOne: false
            referencedRelation: "hospitals"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "patients_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "patients_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      phases: {
        Row: {
          completed_at: string | null
          created_at: string | null
          description: string | null
          id: string
          journey_id: string
          order: number | null
          started_at: string | null
          status: string
          title: string
          updated_at: string | null
          user_id: string
        }
        Insert: {
          completed_at?: string | null
          created_at?: string | null
          description?: string | null
          id?: string
          journey_id: string
          order?: number | null
          started_at?: string | null
          status?: string
          title: string
          updated_at?: string | null
          user_id: string
        }
        Update: {
          completed_at?: string | null
          created_at?: string | null
          description?: string | null
          id?: string
          journey_id?: string
          order?: number | null
          started_at?: string | null
          status?: string
          title?: string
          updated_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "phases_journey_id_fkey"
            columns: ["journey_id"]
            isOneToOne: false
            referencedRelation: "journeys"
            referencedColumns: ["id"]
          },
        ]
      }
      plan_timelines: {
        Row: {
          condition_id: string | null
          created_at: string | null
          id: string
          is_current: boolean | null
          milestones: Json | null
          name: string
          updated_at: string | null
          user_id: string | null
        }
        Insert: {
          condition_id?: string | null
          created_at?: string | null
          id?: string
          is_current?: boolean | null
          milestones?: Json | null
          name: string
          updated_at?: string | null
          user_id?: string | null
        }
        Update: {
          condition_id?: string | null
          created_at?: string | null
          id?: string
          is_current?: boolean | null
          milestones?: Json | null
          name?: string
          updated_at?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "plan_timelines_condition_id_fkey"
            columns: ["condition_id"]
            isOneToOne: false
            referencedRelation: "conditions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "plan_timelines_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      post_likes: {
        Row: {
          created_at: string | null
          id: string
          post_id: string | null
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          post_id?: string | null
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          post_id?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "post_likes_post_id_fkey"
            columns: ["post_id"]
            isOneToOne: false
            referencedRelation: "posts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "post_likes_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      posts: {
        Row: {
          author_id: string | null
          author_image_url: string | null
          author_name: string
          comments_count: number | null
          community_id: string | null
          content: string
          created_at: string | null
          id: string
          image_url: string | null
          likes_count: number | null
          media_type: string | null
          media_url: string | null
          related_conditions: string[] | null
          type: string
          updated_at: string | null
        }
        Insert: {
          author_id?: string | null
          author_image_url?: string | null
          author_name: string
          comments_count?: number | null
          community_id?: string | null
          content: string
          created_at?: string | null
          id?: string
          image_url?: string | null
          likes_count?: number | null
          media_type?: string | null
          media_url?: string | null
          related_conditions?: string[] | null
          type: string
          updated_at?: string | null
        }
        Update: {
          author_id?: string | null
          author_image_url?: string | null
          author_name?: string
          comments_count?: number | null
          community_id?: string | null
          content?: string
          created_at?: string | null
          id?: string
          image_url?: string | null
          likes_count?: number | null
          media_type?: string | null
          media_url?: string | null
          related_conditions?: string[] | null
          type?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "posts_author_id_fkey"
            columns: ["author_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "posts_community_id_fkey1"
            columns: ["community_id"]
            isOneToOne: false
            referencedRelation: "communities"
            referencedColumns: ["id"]
          },
        ]
      }
      projects: {
        Row: {
          created_at: string | null
          created_by: string
          description: string | null
          end_date: string | null
          id: string
          name: string
          start_date: string | null
          status: string | null
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          created_by: string
          description?: string | null
          end_date?: string | null
          id?: string
          name: string
          start_date?: string | null
          status?: string | null
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          created_by?: string
          description?: string | null
          end_date?: string | null
          id?: string
          name?: string
          start_date?: string | null
          status?: string | null
          updated_at?: string | null
        }
        Relationships: []
      }
      recovery_blueprints: {
        Row: {
          care_team: Json
          created_at: string
          daily_routines: Json
          equipment: Json
          home_readiness: Json
          id: string
          independence_assessment: Json
          patient_profile: Json
          roadmap: Json | null
          supplies: Json
          updated_at: string
          updated_by: string | null
          user_id: string
        }
        Insert: {
          care_team?: Json
          created_at?: string
          daily_routines?: Json
          equipment?: Json
          home_readiness?: Json
          id?: string
          independence_assessment?: Json
          patient_profile?: Json
          roadmap?: Json | null
          supplies?: Json
          updated_at?: string
          updated_by?: string | null
          user_id: string
        }
        Update: {
          care_team?: Json
          created_at?: string
          daily_routines?: Json
          equipment?: Json
          home_readiness?: Json
          id?: string
          independence_assessment?: Json
          patient_profile?: Json
          roadmap?: Json | null
          supplies?: Json
          updated_at?: string
          updated_by?: string | null
          user_id?: string
        }
        Relationships: []
      }
      recovery_domains: {
        Row: {
          completed_phases: number | null
          created_at: string | null
          id: string
          last_activity_at: string | null
          total_phases: number | null
          type: string
          updated_at: string | null
          user_id: string
        }
        Insert: {
          completed_phases?: number | null
          created_at?: string | null
          id?: string
          last_activity_at?: string | null
          total_phases?: number | null
          type: string
          updated_at?: string | null
          user_id: string
        }
        Update: {
          completed_phases?: number | null
          created_at?: string | null
          id?: string
          last_activity_at?: string | null
          total_phases?: number | null
          type?: string
          updated_at?: string | null
          user_id?: string
        }
        Relationships: []
      }
      resource_applications: {
        Row: {
          created_at: string | null
          email: string
          id: string
          name: string
          notes: string
          phone: string
          status: string | null
          updated_at: string | null
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          email: string
          id?: string
          name: string
          notes: string
          phone: string
          status?: string | null
          updated_at?: string | null
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          email?: string
          id?: string
          name?: string
          notes?: string
          phone?: string
          status?: string | null
          updated_at?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "resource_applications_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      resource_ratings: {
        Row: {
          avg_app: number | null
          avg_combined: number | null
          avg_google: number | null
          count_app: number | null
          count_combined: number | null
          count_google: number | null
          resource_id: string
          updated_at: string | null
        }
        Insert: {
          avg_app?: number | null
          avg_combined?: number | null
          avg_google?: number | null
          count_app?: number | null
          count_combined?: number | null
          count_google?: number | null
          resource_id: string
          updated_at?: string | null
        }
        Update: {
          avg_app?: number | null
          avg_combined?: number | null
          avg_google?: number | null
          count_app?: number | null
          count_combined?: number | null
          count_google?: number | null
          resource_id?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "resource_ratings_resource_id_fkey"
            columns: ["resource_id"]
            isOneToOne: true
            referencedRelation: "resources"
            referencedColumns: ["id"]
          },
        ]
      }
      resource_suggestions: {
        Row: {
          address: string
          approval_token: string | null
          approved_at: string | null
          approved_by: string | null
          approved_by_uid: string | null
          city: string | null
          contact_email: string | null
          contactemail: string | null
          country: string | null
          created_at: string | null
          created_by: string | null
          created_by_email: string | null
          description: string | null
          id: string
          lat: number | null
          lng: number | null
          name: string
          phone: string | null
          postal_code: string | null
          postalcode: string | null
          published_resource_id: string | null
          rejected_at: string | null
          rejected_by_uid: string | null
          rejected_reason: string | null
          specialties: string[] | null
          state: string | null
          status: string | null
          submitted_by_email: string | null
          submitted_by_uid: string | null
          type: string
          updated_at: string | null
          website: string | null
        }
        Insert: {
          address: string
          approval_token?: string | null
          approved_at?: string | null
          approved_by?: string | null
          approved_by_uid?: string | null
          city?: string | null
          contact_email?: string | null
          contactemail?: string | null
          country?: string | null
          created_at?: string | null
          created_by?: string | null
          created_by_email?: string | null
          description?: string | null
          id?: string
          lat?: number | null
          lng?: number | null
          name: string
          phone?: string | null
          postal_code?: string | null
          postalcode?: string | null
          published_resource_id?: string | null
          rejected_at?: string | null
          rejected_by_uid?: string | null
          rejected_reason?: string | null
          specialties?: string[] | null
          state?: string | null
          status?: string | null
          submitted_by_email?: string | null
          submitted_by_uid?: string | null
          type: string
          updated_at?: string | null
          website?: string | null
        }
        Update: {
          address?: string
          approval_token?: string | null
          approved_at?: string | null
          approved_by?: string | null
          approved_by_uid?: string | null
          city?: string | null
          contact_email?: string | null
          contactemail?: string | null
          country?: string | null
          created_at?: string | null
          created_by?: string | null
          created_by_email?: string | null
          description?: string | null
          id?: string
          lat?: number | null
          lng?: number | null
          name?: string
          phone?: string | null
          postal_code?: string | null
          postalcode?: string | null
          published_resource_id?: string | null
          rejected_at?: string | null
          rejected_by_uid?: string | null
          rejected_reason?: string | null
          specialties?: string[] | null
          state?: string | null
          status?: string | null
          submitted_by_email?: string | null
          submitted_by_uid?: string | null
          type?: string
          updated_at?: string | null
          website?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "resource_suggestions_approved_by_fkey"
            columns: ["approved_by"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "resource_suggestions_approved_by_uid_fkey"
            columns: ["approved_by_uid"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "resource_suggestions_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "resource_suggestions_published_resource_id_fkey"
            columns: ["published_resource_id"]
            isOneToOne: false
            referencedRelation: "resources_curated"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "resource_suggestions_rejected_by_uid_fkey"
            columns: ["rejected_by_uid"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "resource_suggestions_submitted_by_uid_fkey"
            columns: ["submitted_by_uid"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      resources: {
        Row: {
          address: string
          availability: string
          contact_email: string | null
          contact_phone: string | null
          created_at: string | null
          distance: number | null
          id: string
          lat: number | null
          lng: number | null
          location: string
          name: string
          rating: number | null
          review_count: number | null
          specialty: string[] | null
          type: string
          updated_at: string | null
          website: string | null
        }
        Insert: {
          address: string
          availability: string
          contact_email?: string | null
          contact_phone?: string | null
          created_at?: string | null
          distance?: number | null
          id?: string
          lat?: number | null
          lng?: number | null
          location: string
          name: string
          rating?: number | null
          review_count?: number | null
          specialty?: string[] | null
          type: string
          updated_at?: string | null
          website?: string | null
        }
        Update: {
          address?: string
          availability?: string
          contact_email?: string | null
          contact_phone?: string | null
          created_at?: string | null
          distance?: number | null
          id?: string
          lat?: number | null
          lng?: number | null
          location?: string
          name?: string
          rating?: number | null
          review_count?: number | null
          specialty?: string[] | null
          type?: string
          updated_at?: string | null
          website?: string | null
        }
        Relationships: []
      }
      resources_curated: {
        Row: {
          address: string
          availability: string | null
          contact_email: string | null
          contact_phone: string | null
          created_at: string | null
          id: string
          lat: number | null
          lng: number | null
          location: string
          name: string
          rating: number | null
          review_count: number | null
          specialty: string[] | null
          status: string | null
          type: string
          updated_at: string | null
          website: string | null
        }
        Insert: {
          address: string
          availability?: string | null
          contact_email?: string | null
          contact_phone?: string | null
          created_at?: string | null
          id?: string
          lat?: number | null
          lng?: number | null
          location: string
          name: string
          rating?: number | null
          review_count?: number | null
          specialty?: string[] | null
          status?: string | null
          type: string
          updated_at?: string | null
          website?: string | null
        }
        Update: {
          address?: string
          availability?: string | null
          contact_email?: string | null
          contact_phone?: string | null
          created_at?: string | null
          id?: string
          lat?: number | null
          lng?: number | null
          location?: string
          name?: string
          rating?: number | null
          review_count?: number | null
          specialty?: string[] | null
          status?: string | null
          type?: string
          updated_at?: string | null
          website?: string | null
        }
        Relationships: []
      }
      schedules: {
        Row: {
          created_at: string | null
          created_by: string | null
          end_time: string
          hospital_id: string | null
          id: string
          location: string | null
          notes: string | null
          patient_id: string | null
          session_type: string
          staff_id: string | null
          start_time: string
          status: string
          title: string
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          created_by?: string | null
          end_time: string
          hospital_id?: string | null
          id?: string
          location?: string | null
          notes?: string | null
          patient_id?: string | null
          session_type?: string
          staff_id?: string | null
          start_time: string
          status?: string
          title: string
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          created_by?: string | null
          end_time?: string
          hospital_id?: string | null
          id?: string
          location?: string | null
          notes?: string | null
          patient_id?: string | null
          session_type?: string
          staff_id?: string | null
          start_time?: string
          status?: string
          title?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "schedules_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "schedules_hospital_id_fkey"
            columns: ["hospital_id"]
            isOneToOne: false
            referencedRelation: "hospitals"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "schedules_patient_id_fkey"
            columns: ["patient_id"]
            isOneToOne: false
            referencedRelation: "patients"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "schedules_staff_id_fkey"
            columns: ["staff_id"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
        ]
      }
      staff: {
        Row: {
          auth_user_id: string | null
          created_at: string | null
          email: string
          facility_id: string | null
          hospital_id: string | null
          id: string
          invited_at: string | null
          invited_by: string | null
          last_login_at: string | null
          name: string
          organization_id: string | null
          role: string
          status: string
          updated_at: string | null
        }
        Insert: {
          auth_user_id?: string | null
          created_at?: string | null
          email: string
          facility_id?: string | null
          hospital_id?: string | null
          id?: string
          invited_at?: string | null
          invited_by?: string | null
          last_login_at?: string | null
          name: string
          organization_id?: string | null
          role: string
          status?: string
          updated_at?: string | null
        }
        Update: {
          auth_user_id?: string | null
          created_at?: string | null
          email?: string
          facility_id?: string | null
          hospital_id?: string | null
          id?: string
          invited_at?: string | null
          invited_by?: string | null
          last_login_at?: string | null
          name?: string
          organization_id?: string | null
          role?: string
          status?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "staff_facility_id_fkey"
            columns: ["facility_id"]
            isOneToOne: false
            referencedRelation: "facilities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "staff_hospital_id_fkey"
            columns: ["hospital_id"]
            isOneToOne: false
            referencedRelation: "hospitals"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "staff_invited_by_fkey"
            columns: ["invited_by"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "staff_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      strategic_contact_activities: {
        Row: {
          activity_date: string | null
          contact_id: string
          created_at: string | null
          id: string
          summary: string
          type: string
        }
        Insert: {
          activity_date?: string | null
          contact_id: string
          created_at?: string | null
          id?: string
          summary: string
          type: string
        }
        Update: {
          activity_date?: string | null
          contact_id?: string
          created_at?: string | null
          id?: string
          summary?: string
          type?: string
        }
        Relationships: [
          {
            foreignKeyName: "strategic_contact_activities_contact_id_fkey"
            columns: ["contact_id"]
            isOneToOne: false
            referencedRelation: "strategic_contacts"
            referencedColumns: ["id"]
          },
        ]
      }
      strategic_contacts: {
        Row: {
          contact_type: string
          created_at: string | null
          created_by: string | null
          email: string | null
          follow_up_at: string | null
          id: string
          last_contact_at: string | null
          linkedin: string | null
          name: string
          next_step: string | null
          notes: string | null
          organization: string | null
          phone: string | null
          relationship_strength: number | null
          source: string | null
          status: string
          tags: string[] | null
          title: string | null
          updated_at: string | null
        }
        Insert: {
          contact_type?: string
          created_at?: string | null
          created_by?: string | null
          email?: string | null
          follow_up_at?: string | null
          id?: string
          last_contact_at?: string | null
          linkedin?: string | null
          name: string
          next_step?: string | null
          notes?: string | null
          organization?: string | null
          phone?: string | null
          relationship_strength?: number | null
          source?: string | null
          status?: string
          tags?: string[] | null
          title?: string | null
          updated_at?: string | null
        }
        Update: {
          contact_type?: string
          created_at?: string | null
          created_by?: string | null
          email?: string | null
          follow_up_at?: string | null
          id?: string
          last_contact_at?: string | null
          linkedin?: string | null
          name?: string
          next_step?: string | null
          notes?: string | null
          organization?: string | null
          phone?: string | null
          relationship_strength?: number | null
          source?: string | null
          status?: string
          tags?: string[] | null
          title?: string | null
          updated_at?: string | null
        }
        Relationships: []
      }
      tasks: {
        Row: {
          assigned_to: string | null
          created_at: string | null
          created_by: string
          description: string | null
          due_date: string | null
          id: string
          priority: string | null
          project_id: string
          status: string | null
          title: string
          updated_at: string | null
        }
        Insert: {
          assigned_to?: string | null
          created_at?: string | null
          created_by: string
          description?: string | null
          due_date?: string | null
          id?: string
          priority?: string | null
          project_id: string
          status?: string | null
          title: string
          updated_at?: string | null
        }
        Update: {
          assigned_to?: string | null
          created_at?: string | null
          created_by?: string
          description?: string | null
          due_date?: string | null
          id?: string
          priority?: string | null
          project_id?: string
          status?: string | null
          title?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "tasks_project_id_fkey"
            columns: ["project_id"]
            isOneToOne: false
            referencedRelation: "projects"
            referencedColumns: ["id"]
          },
        ]
      }
      tracker_entries: {
        Row: {
          activities: string[] | null
          bladder_success: boolean | null
          bowel_program: boolean | null
          created_at: string | null
          custom_fields: Json | null
          date: string
          diastolic_bp: number | null
          energy_level: number | null
          heart_rate: number | null
          id: string
          medications: string[] | null
          mood: string | null
          notes: string | null
          pain_level: number | null
          pain_map: Json | null
          sign_meta: Json | null
          sleep_quality: number | null
          spasm_frequency: number | null
          steps: number | null
          symptoms: string[] | null
          systolic_bp: number | null
          temperature: number | null
          triggers: string[] | null
          updated_at: string | null
          user_id: string | null
          weight: number | null
        }
        Insert: {
          activities?: string[] | null
          bladder_success?: boolean | null
          bowel_program?: boolean | null
          created_at?: string | null
          custom_fields?: Json | null
          date: string
          diastolic_bp?: number | null
          energy_level?: number | null
          heart_rate?: number | null
          id?: string
          medications?: string[] | null
          mood?: string | null
          notes?: string | null
          pain_level?: number | null
          pain_map?: Json | null
          sign_meta?: Json | null
          sleep_quality?: number | null
          spasm_frequency?: number | null
          steps?: number | null
          symptoms?: string[] | null
          systolic_bp?: number | null
          temperature?: number | null
          triggers?: string[] | null
          updated_at?: string | null
          user_id?: string | null
          weight?: number | null
        }
        Update: {
          activities?: string[] | null
          bladder_success?: boolean | null
          bowel_program?: boolean | null
          created_at?: string | null
          custom_fields?: Json | null
          date?: string
          diastolic_bp?: number | null
          energy_level?: number | null
          heart_rate?: number | null
          id?: string
          medications?: string[] | null
          mood?: string | null
          notes?: string | null
          pain_level?: number | null
          pain_map?: Json | null
          sign_meta?: Json | null
          sleep_quality?: number | null
          spasm_frequency?: number | null
          steps?: number | null
          symptoms?: string[] | null
          systolic_bp?: number | null
          temperature?: number | null
          triggers?: string[] | null
          updated_at?: string | null
          user_id?: string | null
          weight?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "tracker_entries_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      user_achievements: {
        Row: {
          achievement_id: string | null
          created_at: string | null
          id: string
          progress: number | null
          unlocked: boolean | null
          unlocked_at: string | null
          updated_at: string | null
          user_id: string | null
        }
        Insert: {
          achievement_id?: string | null
          created_at?: string | null
          id?: string
          progress?: number | null
          unlocked?: boolean | null
          unlocked_at?: string | null
          updated_at?: string | null
          user_id?: string | null
        }
        Update: {
          achievement_id?: string | null
          created_at?: string | null
          id?: string
          progress?: number | null
          unlocked?: boolean | null
          unlocked_at?: string | null
          updated_at?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "user_achievements_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      user_consent_logs: {
        Row: {
          action: string
          consent_method: string | null
          created_at: string | null
          device_info: Json | null
          document_id: string
          document_type: string
          document_version: string
          id: string
          ip_address: string | null
          location_data: Json | null
          notes: string | null
          user_agent: string | null
          user_id: string
        }
        Insert: {
          action: string
          consent_method?: string | null
          created_at?: string | null
          device_info?: Json | null
          document_id: string
          document_type: string
          document_version: string
          id?: string
          ip_address?: string | null
          location_data?: Json | null
          notes?: string | null
          user_agent?: string | null
          user_id: string
        }
        Update: {
          action?: string
          consent_method?: string | null
          created_at?: string | null
          device_info?: Json | null
          document_id?: string
          document_type?: string
          document_version?: string
          id?: string
          ip_address?: string | null
          location_data?: Json | null
          notes?: string | null
          user_agent?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_consent_logs_document_id_fkey"
            columns: ["document_id"]
            isOneToOne: false
            referencedRelation: "consent_documents"
            referencedColumns: ["id"]
          },
        ]
      }
      user_consent_status: {
        Row: {
          consent_method: string | null
          consented_at: string
          document_id: string
          document_type: string
          document_version: string
          id: string
          ip_address: string | null
          is_consented: boolean | null
          last_updated_at: string | null
          user_agent: string | null
          user_id: string
        }
        Insert: {
          consent_method?: string | null
          consented_at: string
          document_id: string
          document_type: string
          document_version: string
          id?: string
          ip_address?: string | null
          is_consented?: boolean | null
          last_updated_at?: string | null
          user_agent?: string | null
          user_id: string
        }
        Update: {
          consent_method?: string | null
          consented_at?: string
          document_id?: string
          document_type?: string
          document_version?: string
          id?: string
          ip_address?: string | null
          is_consented?: boolean | null
          last_updated_at?: string | null
          user_agent?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_consent_status_document_id_fkey"
            columns: ["document_id"]
            isOneToOne: false
            referencedRelation: "consent_documents"
            referencedColumns: ["id"]
          },
        ]
      }
      user_roles: {
        Row: {
          created_at: string | null
          email: string
          facility_id: string | null
          hospital_code: string | null
          id: string
          organization_id: string | null
          portal: string
          role: string
          status: string | null
          updated_at: string | null
          user_id: string
        }
        Insert: {
          created_at?: string | null
          email: string
          facility_id?: string | null
          hospital_code?: string | null
          id?: string
          organization_id?: string | null
          portal: string
          role: string
          status?: string | null
          updated_at?: string | null
          user_id: string
        }
        Update: {
          created_at?: string | null
          email?: string
          facility_id?: string | null
          hospital_code?: string | null
          id?: string
          organization_id?: string | null
          portal?: string
          role?: string
          status?: string | null
          updated_at?: string | null
          user_id?: string
        }
        Relationships: []
      }
      users: {
        Row: {
          auth_user_id: string
          conditions: string[] | null
          created_at: string | null
          diagnosis_date: string | null
          email: string
          id: string
          interests: string[] | null
          medications: Json | null
          name: string
          onboarding_completed: boolean | null
          patient_code: string | null
          preferences: Json | null
          profile_image_url: string | null
          role: string
          updated_at: string | null
        }
        Insert: {
          auth_user_id: string
          conditions?: string[] | null
          created_at?: string | null
          diagnosis_date?: string | null
          email: string
          id?: string
          interests?: string[] | null
          medications?: Json | null
          name: string
          onboarding_completed?: boolean | null
          patient_code?: string | null
          preferences?: Json | null
          profile_image_url?: string | null
          role?: string
          updated_at?: string | null
        }
        Update: {
          auth_user_id?: string
          conditions?: string[] | null
          created_at?: string | null
          diagnosis_date?: string | null
          email?: string
          id?: string
          interests?: string[] | null
          medications?: Json | null
          name?: string
          onboarding_completed?: boolean | null
          patient_code?: string | null
          preferences?: Json | null
          profile_image_url?: string | null
          role?: string
          updated_at?: string | null
        }
        Relationships: []
      }
      work_logs: {
        Row: {
          created_at: string | null
          description: string | null
          employee_id: string | null
          hours: number
          id: string
          log_date: string
          project: string | null
          status: string | null
          title: string
        }
        Insert: {
          created_at?: string | null
          description?: string | null
          employee_id?: string | null
          hours: number
          id?: string
          log_date?: string
          project?: string | null
          status?: string | null
          title: string
        }
        Update: {
          created_at?: string | null
          description?: string | null
          employee_id?: string | null
          hours?: number
          id?: string
          log_date?: string
          project?: string | null
          status?: string | null
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "work_logs_employee_id_fkey"
            columns: ["employee_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      approve_suggestion_and_publish: {
        Args: {
          approved_by_uid: string
          curated_resource: Json
          suggestion_id: string
        }
        Returns: string
      }
      cleanup_expired_mfa_codes: { Args: never; Returns: undefined }
      find_patient_by_code: {
        Args: { p_code: string }
        Returns: {
          created_at: string
          email: string
          first_name: string
          id: string
          last_name: string
          name: string
          patient_code: string
        }[]
      }
      get_my_staff_record: {
        Args: never
        Returns: {
          hospital_id: string
          id: string
          role: string
          status: string
        }[]
      }
      get_user_facility_ids: {
        Args: never
        Returns: {
          facility_id: string
        }[]
      }
      is_blueprint_collaborator: { Args: { bp_id: string }; Returns: boolean }
      is_blueprint_editor: { Args: { bp_id: string }; Returns: boolean }
      is_blueprint_owner: { Args: { bp_id: string }; Returns: boolean }
      is_org_admin: { Args: { org_id: string }; Returns: boolean }
      lookup_patient_by_access_code: {
        Args: { p_code: string }
        Returns: {
          first_name: string
          id: string
          last_name: string
        }[]
      }
      lookup_patient_by_code: {
        Args: { search_code: string }
        Returns: {
          created_at: string
          email: string
          first_name: string
          id: string
          last_name: string
          name: string
          patient_code: string
        }[]
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {},
  },
} as const
