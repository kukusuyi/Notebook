import { beforeEach, describe, expect, it, vi } from 'vitest'
import { appearance, appearanceKey, defaults, normalizeAppearance, paletteFor, setAppearance, themes } from './appearance'
function luminance(hex:string){const c=hex.slice(1).match(/../g)!.map(x=>parseInt(x,16)/255).map(x=>x<=.04045?x/12.92:((x+.055)/1.055)**2.4);return .2126*c[0]+.7152*c[1]+.0722*c[2]}
function contrast(a:string,b:string){const x=luminance(a),y=luminance(b);return(Math.max(x,y)+.05)/(Math.min(x,y)+.05)}
beforeEach(()=>{vi.stubGlobal('matchMedia',()=>({matches:false,addEventListener:vi.fn()}));localStorage.clear()})
describe('appearance',()=>{
 for(const preset of Object.keys(themes) as (keyof typeof themes)[])for(const dark of [false,true])for(const accentSeed of [null,'#000000','#ffffff','#ffff00'])it(`${preset} ${dark?'dark':'light'} ${accentSeed} readable`,()=>{const c=paletteFor({...defaults,preset,accentSeed},dark);for(const [a,b] of [[c.text,c.surface],[c.muted,c.surface],[c.primary,c.onPrimary],[c.primary,c.soft]])expect(contrast(a,b)).toBeGreaterThanOrEqual(4.5)})
 it('validates corrupt preferences',()=>{expect(normalizeAppearance({preset:'invalid',mode:'invalid',accentSeed:'red'})).toEqual(defaults)})
 it('persists, applies and resets preferences without changing authentication',()=>{localStorage.setItem('token','unchanged');setAppearance({preset:'paper',mode:'dark',accentSeed:'#FFFF00'});expect(JSON.parse(localStorage.getItem(appearanceKey)!)).toEqual({...defaults,preset:'paper',mode:'dark',accentSeed:'#FFFF00'});expect(document.documentElement.classList.contains('dark')).toBe(true);expect(document.documentElement.dataset.theme).toBe('paper');setAppearance(defaults);expect({...appearance}).toEqual(defaults);expect(localStorage.getItem('token')).toBe('unchanged')})
})
