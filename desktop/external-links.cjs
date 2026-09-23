const hosts=new Set(['account.aliyun.com','bailian.console.aliyun.com','help.aliyun.com']);
exports.isTrustedExternal=function(raw){try{const u=new URL(raw);return u.protocol==='https:'&&!u.username&&!u.password&&!u.port&&hosts.has(u.hostname)}catch{return false}};
