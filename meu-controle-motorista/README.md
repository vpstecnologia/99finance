# Meu Controle Motorista — Versão inicial

Sistema web para motoristas da 99, com contas independentes, login obrigatório e painel administrativo. **Projeto novo:** não depende do sistema anterior.

## Funcionalidades incluídas
- Cadastro, login, confirmação de e-mail e recuperação de senha via Supabase Auth.
- Lançamentos diários com edição e exclusão; faturamento, km, média km/l e preço do combustível (padrão editável por lançamento).
- Despesas avulsas, com edição e exclusão.
- Painel diário/semanal/mensal: faturamento, combustível estimado, despesas e lucro operacional.
- Manutenções planejadas por data e/ou odômetro, com sugestão de reserva por dia trabalhado.
- Reserva personalizada e registro separado de dinheiro efetivamente guardado ou retirado.
- Escala padrão de 6 dias/semana e demais preferências por motorista.
- Admin pode listar perfis e ativar/desativar contas; não visualiza finanças alheias.
- Políticas RLS no banco de dados.

## Iniciar localmente
1. Instale Node.js 20 ou superior.
2. Crie um projeto **novo** em https://supabase.com .
3. No Supabase → SQL Editor, execute `supabase/schema.sql` **uma única vez**.
4. Em Authentication → Providers → Email, habilite confirmação de e-mail (recomendado).
5. Configure Authentication → URL Configuration com o endereço local e, depois, a URL final da Vercel (Redirect URLs). Para redefinição de senha, configure corretamente os redirecionamentos do projeto.
6. Copie `.env.example` para `.env.local`, preenchendo a URL do projeto e a chave pública (`anon`/publishable). **Nunca utilize `service_role` no navegador.**
7. No terminal:

```bash
npm install
npm run dev
```

8. Acesse http://localhost:3000 e cadastre sua conta com e-mail.
9. Após confirmar o cadastro, no SQL Editor do Supabase, execute **substituindo o e-mail**:

```sql
insert into public.admin_users(user_id)
select id from auth.users where email = 'SEU_EMAIL_AQUI'
on conflict do nothing;
```

10. Saia e entre novamente no sistema. Aparecerá a aba **Administração**.

## Publicação independente
1. Crie um **novo repositório** no GitHub e envie estes arquivos; não envie `.env.local`.
2. Importe o repositório em um **novo projeto** Vercel (framework Next.js).
3. Defina `NEXT_PUBLIC_SUPABASE_URL` e `NEXT_PUBLIC_SUPABASE_ANON_KEY` nas variáveis de ambiente da Vercel.
4. Publique e ajuste as Redirect URLs do Supabase para o novo endereço.
5. Valide login, confirmação de e-mail, contas isoladas, admin e todos os cálculos antes de usar dados reais.

## Regras financeiras atuais
- Combustível estimado = km rodados ÷ consumo km/l × preço/litro.
- Lucro operacional no período = faturamento − custo estimado do combustível − despesas registradas.
- Reserva de manutenção sugerida por dia = max(0, custo previsto − saldo efetivamente registrado) ÷ dias de trabalho previstos até o vencimento.
- Dias até o vencimento = menor entre dias de trabalho previstos por data ou por km (quando informados). Para km, utiliza a média diária configurada. A previsão é aproximada e deve ser reavaliada quando houver mudança da rotina.
- A reserva **sugerida** não é debitada automaticamente do lucro nem tratada como dinheiro guardado. Só a movimentação explícita altera o saldo das reservas.
- Uma despesa de manutenção reduz o lucro operacional; a retirada da respectiva reserva movimenta apenas o saldo reservado, evitando dupla contagem no lucro.
- Odômetro estimado = odômetro de referência + soma dos km dos lançamentos. Defina a referência **antes de começar**; se alterar depois, a estimativa somará os registros novamente.

## Limitações e próximas melhorias
Esta é uma **primeira versão funcional de código**, não um serviço já publicado. Os testes de execução e integração devem ocorrer após `npm install` e configuração do Supabase. A recuperação de senha por e-mail está integrada ao Supabase, mas a tela de definir nova senha após clicar no link ainda precisa ser adicionada. Não há histórico automático de ciclos concluídos de manutenção, conciliação de depósitos reais com bancos, nem notificações push. Também é recomendável acrescentar testes automatizados, exportação CSV, filtros customizados e migrações versionadas antes de uso intensivo.

## Segurança
- Não compartilhar senha de GitHub/Supabase/Vercel, e jamais publicar `service_role`.
- Confirmação de e-mail e RLS são indispensáveis para produção.
- Somente o SQL Editor, de forma autenticada como proprietário, deve cadastrar o primeiro administrador.
- Faça testes com dois usuários diferentes para confirmar que um não acessa os registros do outro.


## Atualização V2 — Abastecimentos (banco existente)

**Não execute `supabase/schema.sql` novamente no projeto que já está em uso.**

1. Faça um backup do banco no Supabase antes de migrar e preserve sua versão atual publicada.
2. No Supabase do sistema atual, abra SQL Editor e execute **somente** `supabase/migrations/002_refuelings.sql`.
3. Atualize os arquivos da aplicação no mesmo repositório GitHub, preservando as variáveis de ambiente já configuradas. Na Vercel, publique novamente.
4. Teste com seu login o cadastro/edição/exclusão de abastecimentos, o preço sugerido e a visualização do histórico. Teste com um segundo motorista para validar RLS.
5. Se a consulta a `refuelings` resultar em erro `relation does not exist`, a migração ainda não foi executada no projeto correto.

**Lógica:** o preço do abastecimento mais recente (por data, depois criação) é sugerido para lançamentos novos. Lançamentos anteriores continuam com seu preço salvo. Abastecimentos são fluxo de caixa separado: não são nova despesa no lucro, para não haver desconto duplicado. O custo diário continua km ÷ km/l × preço. O consumo real é medido por ciclos entre abastecimentos de tanque cheio, incluindo abastecimentos parciais no intervalo. Registros fora de ordem ou odômetros incorretos podem invalidar a média. O painel mostra valor e litros abastecidos no período e a última média real válida.

**Nota:** o preço mais recente não sobrescreve automaticamente um formulário diário que já esteja em edição. Use “Cancelar edição” para abrir um novo registro com o preço mais recente.
