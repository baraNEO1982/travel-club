export interface EmailEnv { BREVO_API_KEY?:string; EMAIL_FROM?:string; }
export function emailReady(env:EmailEnv){return !!env.BREVO_API_KEY&&!!env.EMAIL_FROM;}
export async function sendAccountEmail(env:EmailEnv,to:string,link:string,purpose:'verify'|'reset'){
 if(!emailReady(env))throw new Error('Email is not configured');
 const subject=purpose==='verify'?'Подтвердите почту — Клуб путешественников':'Восстановление пароля — Клуб путешественников';
 const textContent=purpose==='verify'?`Вы привязываете эту почту к своему профилю в Клубе путешественников.\n\nПодтвердите адрес: ${link}\n\nСсылка действует 30 минут и используется один раз. Если вы не запрашивали привязку, ничего не нажимайте.`:`Чтобы задать новый пароль Клуба путешественников, откройте ссылку:\n\n${link}\n\nСсылка действует 30 минут и используется один раз. Если вы не запрашивали сброс пароля, проигнорируйте письмо — пароль останется прежним.`;
 const response=await fetch('https://api.brevo.com/v3/smtp/email',{method:'POST',headers:{'api-key':env.BREVO_API_KEY!,'Content-Type':'application/json'},body:JSON.stringify({sender:{name:'Клуб путешественников',email:env.EMAIL_FROM},to:[{email:to}],subject,textContent}),signal:AbortSignal.timeout(15000)});
 if(!response.ok)throw new Error('Email provider rejected the request');
}
