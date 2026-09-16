import { createClient } from '@supabase/supabase-js';
export const supabase = createClient('https://ipsiphmdusklqjlquyjq.supabase.co','sb_publishable_ewuYZeVpuDEHqiVJTUMfjA_cob_Hfpi', {auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}});
