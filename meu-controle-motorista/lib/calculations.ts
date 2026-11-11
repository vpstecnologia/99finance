export type MaintenancePlan={id:string;name:string;estimated_cost:number;due_date:string|null;due_odometer:number|null;active:boolean;created_at:string};
export type DriverSettings={fuel_price:number;km_per_liter:number;daily_goal:number;work_days_per_week:number;current_odometer:number;average_km_per_work_day:number};
export const money=(n:number)=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(n||0);
export const round=(n:number)=>Math.round((n+Number.EPSILON)*100)/100;
export const number=(v:string|number|null|undefined)=>Math.max(0,Number(String(v??'').replace(',','.'))||0);
export function workDaysUntil(date:string|null,daysPerWeek:number){
 if(!date)return Infinity;
 const end=new Date(date+'T12:00:00'); const today=new Date();today.setHours(12,0,0,0);
 const total=Math.max(1,Math.ceil((end.getTime()-today.getTime())/86400000));
 return Math.max(1,Math.ceil(total*daysPerWeek/7));
}
export function planDailyReserve(p:MaintenancePlan,s:DriverSettings,saved:number,odometer:number){
 const remaining=Math.max(0,p.estimated_cost-saved);
 const timeDays=workDaysUntil(p.due_date,s.work_days_per_week);
 const kmDays=p.due_odometer==null?Infinity:Math.max(1,Math.ceil((p.due_odometer-odometer)/Math.max(1,s.average_km_per_work_day)));
 const days=Math.min(timeDays,kmDays);
 return {days:Number.isFinite(days)?days:null,amount:Number.isFinite(days)?round(remaining/days):0,remaining};
}
