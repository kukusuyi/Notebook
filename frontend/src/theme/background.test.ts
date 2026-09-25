// @vitest-environment jsdom
import {expect,it} from 'vitest'
import {backgroundLimit,validateBackground} from './background'
it('accepts the exact 10 MiB boundary and rejects oversize and non-images',()=>{
 expect(()=>validateBackground(new Blob([new Uint8Array(backgroundLimit)],{type:'image/png'}))).not.toThrow();
 expect(()=>validateBackground(new Blob([new Uint8Array(backgroundLimit+1)],{type:'image/png'}))).toThrow('10 MB');
 expect(()=>validateBackground(new Blob(['x'],{type:'image/svg+xml'}))).toThrow();
})
