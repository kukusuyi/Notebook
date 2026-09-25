const hosts=new Set(['account.aliyun.com','bailian.console.aliyun.com','help.aliyun.com']);
exports.isTrustedExternal=function(raw){try{const u=new URL(raw);return u.protocol==='https:'&&!u.username&&!u.password&&!u.port&&(hosts.has(u.hostname)||(u.hostname==='github.com'&&u.pathname.startsWith('/kukusuyi/Questrace/releases/')))}catch{return false}};
