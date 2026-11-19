// K.I.T.A Movie Booking v2 — GitHub Pages + Supabase
const SUPABASE_URL = 'https://veijexflgbonubokfbwf.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_-VB4AhO-w5QzPAA_r1UTCA_lUf57u-e';
const ready = SUPABASE_URL.startsWith('https://') && !SUPABASE_URL.includes('PASTE_') && !SUPABASE_ANON_KEY.includes('PASTE_');
const db = ready ? window.supabase.createClient(SUPABASE_URL,SUPABASE_ANON_KEY) : null;
const $ = id => document.getElementById(id);
const money = n => `RM${Number(n).toFixed(2)}`;
let studentId=null, options=[], selectedOption=null, adminUser=null;
function toast(s){const el=$('toast');el.textContent=s;el.classList.add('show');setTimeout(()=>el.classList.remove('show'),3500)}
function food(){return document.querySelector('input[name="food"]:checked')?.value||'none'}
function total(){return 1+(food()==='adik'?3:food()==='abang'?5:0)}
function summary(){const o=selectedOption, f=food();$('order-summary').innerHTML=o?`<div class="summary-row"><span>Murid</span><b>${$('student-select').selectedOptions[0]?.textContent||'—'}</b></div><div class="summary-row"><span>Filem</span><b>${o.movie_title}</b></div><div class="summary-row"><span>Tarikh / Sesi</span><b>${o.screening_date} · Sesi ${o.session_no}</b></div><div class="summary-row"><span>Hall</span><b>Hall ${o.hall} · Free seating</b></div><div class="summary-row"><span>Tiket + makanan</span><b>${money(total())}</b></div><div class="summary-row summary-total"><span>Jumlah</span><b>${money(total())}</b></div>`:'Pilih maklumat tempahan untuk melihat ringkasan.'}
async function init(){
 if(!db){$('availability').textContent='Mod pratonton. Sambungkan Supabase dalam assets/js/app.js untuk mengaktifkan tempahan.';return}
 const {data:classes,error}=await db.rpc('get_student_classes');
 if(error){toast('Tidak dapat memuatkan kelas. Semak tetapan Supabase.');return}
 classes.forEach(x=>{const op=new Option(x.class_name,x.class_name);$('class-select').add(op)});
 const {data:movies}=await db.from('movies').select('title,category').eq('is_active',true).order('title');
 $('movie-grid').innerHTML=(movies||[]).map(m=>`<article class="movie-card"><div class="movie-placeholder blue">${escapeHtml(m.title.split(' ').slice(0,2).join(' ').toUpperCase())}</div><div class="movie-info"><h3>${escapeHtml(m.title)}</h3><span>${escapeHtml(m.category||'Filem')}</span></div></article>`).join('');
}
$('class-select').addEventListener('change',async()=>{
 studentId=null;$('student-select').innerHTML='<option value="">Memuatkan nama...</option>';$('student-select').disabled=true;
 if(!db||!$('class-select').value)return;
 const {data,error}=await db.rpc('get_students_by_class',{p_class:$('class-select').value});
 $('student-select').innerHTML='<option value="">Pilih nama murid</option>';
 if(error){toast('Senarai nama tidak dapat dimuatkan.');return}
 (data||[]).forEach(s=>{$('student-select').add(new Option(s.student_name,s.student_id))});
 $('student-select').disabled=false;
});
$('student-select').addEventListener('change',()=>{studentId=$('student-select').value||null;summary()});
$('date-select').addEventListener('change',async()=>{
 $('session-select').innerHTML='<option value="">Pilih sesi</option>';$('session-select').disabled=true;
 $('option-select').innerHTML='<option value="">Pilih sesi dahulu</option>';$('option-select').disabled=true;options=[];selectedOption=null;
 if(!db||!$('date-select').value)return;
 const {data,error}=await db.from('screening_sessions').select('*').eq('screening_date',$('date-select').value).eq('is_open',true).order('session_no');
 if(error){toast('Jadual tidak dapat dimuatkan.');return}
 (data||[]).forEach(s=>$('session-select').add(new Option(`Sesi ${s.session_no} · ${s.start_time.slice(0,5)}–${s.end_time.slice(0,5)}`,s.id)));
 $('session-select').disabled=false;
});
$('session-select').addEventListener('change',loadOptions);
async function loadOptions(){
 selectedOption=null;options=[];$('option-select').innerHTML='<option value="">Memuatkan filem...</option>';$('option-select').disabled=true;summary();
 if(!db||!$('session-select').value)return;
 const {data,error}=await db.from('public_screening_availability').select('*').eq('session_id',$('session-select').value).eq('is_open',true).order('movie_title');
 if(error){$('availability').textContent='Tidak dapat memuatkan pilihan filem.';return}
 options=data||[];$('option-select').innerHTML='<option value="">Pilih filem</option>';
 options.forEach(o=>{const label=`${o.movie_title} · Hall ${o.hall} · ${o.spaces_left} tempat kosong`;const opt=new Option(label,o.screening_option_id);if(o.spaces_left<=0){opt.disabled=true;opt.textContent+= ' (PENUH)'}$('option-select').add(opt)});
 $('option-select').disabled=false;
 $('availability').textContent=options.length? 'Pilih filem. Hall ditetapkan oleh admin dan tempat duduk adalah bebas.':'Belum ada filem/hall ditetapkan oleh admin untuk sesi ini.';
}
$('option-select').addEventListener('change',()=>{selectedOption=options.find(o=>o.screening_option_id===$('option-select').value)||null;if(selectedOption){$('availability').textContent=selectedOption.spaces_left>0?`Hall ${selectedOption.hall} · ${selectedOption.spaces_left}/${selectedOption.capacity} tempat masih tersedia · Free seating.`:'Hall penuh. Sila pilih sesi atau filem lain.'}summary()});
document.querySelectorAll('input[name="food"]').forEach(x=>x.addEventListener('change',summary));
$('booking-form').addEventListener('submit',async e=>{
 e.preventDefault();
 if(!db){toast('Sistem belum disambungkan ke Supabase.');return}
 if(!studentId||!selectedOption||!$('confirm-info').checked){toast('Sila lengkapkan maklumat murid, filem dan pengesahan.');return}
 const f=food(),drink=f==='adik'?$('adik-drink').value:f==='abang'?$('abang-drink').value:null;
 const btn=e.submitter;btn.disabled=true;btn.textContent='Sedang menghantar...';
 const {data,error}=await db.rpc('create_student_booking',{p_student_id:studentId,p_screening_option_id:selectedOption.screening_option_id,p_food_package:f,p_drink_flavour:drink});
 btn.disabled=false;btn.textContent='Hantar tempahan →';
 if(error){const msg=error.message||'';toast(msg.includes('HALL_FULL')?'Maaf, hall ini telah penuh. Sila pilih filem atau sesi lain.':msg.includes('ONE_PER_SESSION')?'Murid ini sudah membuat tempahan bagi sesi tersebut.':`Tempahan gagal: ${msg}`);await loadOptions();return}
 const r=data?.[0]||data;showTicket(r);await loadOptions();
});
function showTicket(r){$('ticket-content').innerHTML=`<span class="eyebrow">TEMPAHAN BERJAYA</span><h2>Tiket K.I.T.A anda</h2><div class="ticket-head"><span>BOOKING REFERENCE</span><br><b>${escapeHtml(r.booking_code)}</b><p>SK SERI MENDAPAT · K.I.T.A MOVIE</p></div><div class="ticket-details"><div><span>NAMA MURID</span><b>${escapeHtml($('student-select').selectedOptions[0].textContent)}</b></div><div><span>FILEM</span><b>${escapeHtml(r.movie_title)}</b></div><div><span>TARIKH / SESI</span><b>${r.screening_date} · Sesi ${r.session_no}</b></div><div><span>HALL</span><b>Hall ${r.hall} · Free seating</b></div><div><span>STATUS BAYARAN</span><b class="status-unpaid">BELUM BAYAR</b></div><div><span>JUMLAH</span><b>${money(r.total_amount)}</b></div></div><div class="qr-area"><div><b>Tunjukkan tiket ini di kaunter</b><p>Bayaran tunai · Tiada nombor kerusi ditetapkan</p></div><div id="qrcode"></div></div><p class="tiny">Simpan nombor rujukan ini untuk semakan bayaran.</p>`;new QRCode($('qrcode'),{text:r.qr_token||r.booking_code,width:104,height:104});$('ticket-dialog').showModal()}
function escapeHtml(s=''){return String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}
document.querySelectorAll('[data-close]').forEach(b=>b.addEventListener('click',()=>$(b.dataset.close).close()));
$('admin-open').addEventListener('click',()=>{$('admin-dialog').showModal()});
$('admin-login').addEventListener('submit',async e=>{e.preventDefault();if(!db){$('admin-message').textContent='Sambungkan Supabase dahulu.';return}const {data,error}=await db.auth.signInWithPassword({email:$('admin-email').value,password:$('admin-password').value});if(error){$('admin-message').textContent=error.message;return}adminUser=data.user;await renderAdmin()});
async function renderAdmin(){
 const [{data:bookings,error:bErr},{data:sessions},{data:movies}]=await Promise.all([
 db.from('admin_booking_overview').select('*').order('created_at',{ascending:false}).limit(500),
 db.from('screening_sessions').select('*').order('screening_date').order('session_no'),
 db.from('movies').select('id,title').eq('is_active',true).order('title')]);
 if(bErr){$('admin-message').textContent='Akses admin tidak dibenarkan. Pastikan UUID akaun telah didaftarkan dalam jadual admins.';return}
 const {data:assigned}=await db.from('screening_options').select('id,session_id,movie_id,hall,capacity');
 $('admin-content').innerHTML=`<span class="eyebrow">PENGURUSAN K.I.T.A</span><h2>Dashboard admin</h2><div class="admin-actions"><button class="mini-btn" id="admin-refresh">Muat semula</button><button class="mini-btn" id="admin-logout">Log keluar</button></div>
 <h3>Tetapan filem dan hall</h3><p class="tiny muted">Tetapkan satu filem kepada Hall A dan/atau Hall B untuk setiap sesi. Setiap hall hanya boleh menayangkan satu filem pada satu sesi.</p>
 <form id="assign-form" class="admin-login"><label>Sesi<select id="a-session" required>${(sessions||[]).map(s=>`<option value="${s.id}">${s.screening_date} · Sesi ${s.session_no} (${s.start_time.slice(0,5)}–${s.end_time.slice(0,5)})</option>`).join('')}</select></label><label>Filem<select id="a-movie" required>${(movies||[]).map(m=>`<option value="${m.id}">${escapeHtml(m.title)}</option>`).join('')}</select></label><label>Hall<select id="a-hall"><option value="A">Hall A · 40 orang</option><option value="B">Hall B · 35 orang</option></select></label><button class="btn btn-primary">Simpan tetapan</button></form>
 <h3>Senarai tetapan aktif</h3><div class="admin-table-wrap"><table class="admin-table"><thead><tr><th>Sesi</th><th>Filem</th><th>Hall</th><th>Kapasiti</th></tr></thead><tbody>${(assigned||[]).map(a=>{const s=sessions.find(x=>x.id===a.session_id),m=movies.find(x=>x.id===a.movie_id);return `<tr><td>${s?.screening_date||''} · S${s?.session_no||''}</td><td>${escapeHtml(m?.title||'')}</td><td>${a.hall}</td><td>${a.capacity}</td></tr>`}).join('')}</tbody></table></div>
 <h3>Rekod tempahan dan bayaran</h3><div class="admin-table-wrap"><table class="admin-table"><thead><tr><th>Nama / Kelas</th><th>Filem / Sesi / Hall</th><th>Jumlah</th><th>Status</th><th>Tindakan</th></tr></thead><tbody>${(bookings||[]).map(b=>`<tr><td><b>${escapeHtml(b.student_name)}</b><br>${escapeHtml(b.class_name)}</td><td>${escapeHtml(b.movie_title)}<br>${b.screening_date} · S${b.session_no} · Hall ${b.hall}</td><td>${money(b.total_amount)}</td><td class="${b.payment_status==='paid'?'status-paid':'status-unpaid'}">${b.payment_status==='paid'?'DIBAYAR':'BELUM BAYAR'}</td><td>${b.payment_status==='paid'?'—':`<button class="mini-btn" data-paid="${b.id}">Tandakan dibayar</button>`}</td></tr>`).join('')}</tbody></table></div>`;
 $('admin-refresh').onclick=renderAdmin;$('admin-logout').onclick=async()=>{await db.auth.signOut();$('admin-content').innerHTML='<p>Anda telah log keluar.</p>'};
 $('assign-form').onsubmit=async ev=>{ev.preventDefault();const hall=$('a-hall').value;const {error}=await db.rpc('admin_set_screening',{p_session_id:$('a-session').value,p_movie_id:$('a-movie').value,p_hall:hall,p_capacity:hall==='A'?40:35});if(error){toast(error.message);return}toast('Tetapan filem dan hall disimpan.');renderAdmin()};
 document.querySelectorAll('[data-paid]').forEach(b=>b.onclick=async()=>{const {error}=await db.rpc('mark_student_booking_paid',{p_booking_id:b.dataset.paid});if(error){toast(error.message);return}toast('Status bayaran dikemaskini.');renderAdmin()});
}
init();
