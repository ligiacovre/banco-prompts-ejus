-- =============================================================
-- BANCO DE PROMPTS EJUS/TJSP — Schema SQL
-- Execute este script no Supabase SQL Editor
-- Dashboard > SQL Editor > New query > Cole e execute
-- =============================================================

-- 1. TABELA: profiles (dados dos usuarios)
CREATE TABLE IF NOT EXISTS profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    email TEXT NOT NULL,
    full_name TEXT,
    role TEXT DEFAULT 'student' CHECK (role IN ('admin', 'student')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. TABELA: prompts (biblioteca oficial — so admin publica)
CREATE TABLE IF NOT EXISTS prompts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL,
    category TEXT NOT NULL,
    description TEXT,
    content TEXT NOT NULL,
    is_published BOOLEAN DEFAULT true,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. TABELA: community_prompts (prompts da comunidade)
CREATE TABLE IF NOT EXISTS community_prompts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL,
    category TEXT NOT NULL,
    description TEXT,
    content TEXT NOT NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    author_name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. TABELA: personal_prompts (biblioteca pessoal de cada aluno)
CREATE TABLE IF NOT EXISTS personal_prompts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL,
    category TEXT NOT NULL,
    description TEXT,
    content TEXT NOT NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================================
-- ROW LEVEL SECURITY (RLS)
-- =============================================================

-- Ativar RLS em todas as tabelas
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE prompts ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_prompts ENABLE ROW LEVEL SECURITY;
ALTER TABLE personal_prompts ENABLE ROW LEVEL SECURITY;

-- PROFILES: usuario ve e edita apenas o proprio perfil
CREATE POLICY "Users can view own profile"
    ON profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
    ON profiles FOR UPDATE
    USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
    ON profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

-- PROMPTS OFICIAIS: todos logados podem ler, so admin insere/edita/deleta
CREATE POLICY "Anyone authenticated can read published prompts"
    ON prompts FOR SELECT
    USING (auth.role() = 'authenticated' AND is_published = true);

CREATE POLICY "Admin can insert prompts"
    ON prompts FOR INSERT
    WITH CHECK (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

CREATE POLICY "Admin can update prompts"
    ON prompts FOR UPDATE
    USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

CREATE POLICY "Admin can delete prompts"
    ON prompts FOR DELETE
    USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- COMMUNITY PROMPTS: todos logados podem ler e criar, so o autor ou admin deleta
CREATE POLICY "Anyone authenticated can read community prompts"
    ON community_prompts FOR SELECT
    USING (auth.role() = 'authenticated');

CREATE POLICY "Anyone authenticated can create community prompts"
    ON community_prompts FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Author or admin can delete community prompts"
    ON community_prompts FOR DELETE
    USING (
        auth.uid() = user_id
        OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- PERSONAL PROMPTS: usuario ve, cria, edita e deleta apenas os proprios
CREATE POLICY "Users can read own personal prompts"
    ON personal_prompts FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create own personal prompts"
    ON personal_prompts FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own personal prompts"
    ON personal_prompts FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own personal prompts"
    ON personal_prompts FOR DELETE
    USING (auth.uid() = user_id);

-- =============================================================
-- TRIGGER: Auto-criar perfil quando usuario se registra
-- =============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name, role)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
        'student'
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Remover trigger se ja existe (para reexecutar sem erro)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- =============================================================
-- DEFINIR VOCE COMO ADMIN (substitua pelo seu email)
-- Execute DEPOIS de ter feito o primeiro cadastro
-- =============================================================
-- UPDATE profiles SET role = 'admin' WHERE email = 'SEU_EMAIL_AQUI@exemplo.com';
