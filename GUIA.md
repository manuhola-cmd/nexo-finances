# Guía para poner la app en marcha

Son 2 archivos: `schema.sql` (prepara la base de datos) y `index.html` (la app completa). No hay que instalar nada en tu computadora. Calcula unos 30 minutos.

> **Importante:** si en Supabase ya tienes un proyecto que empezaste con ChatGPT, crea un **proyecto nuevo**. Las tablas viejas pueden chocar con estas.

---

## Paso 1: Preparar Supabase

1. Entra a [supabase.com](https://supabase.com) y haz clic en **New project**. Ponle un nombre (por ejemplo `nexo-finances`), crea una contraseña para la base de datos y guárdala. Espera 1–2 minutos a que termine.
2. En el menú de la izquierda, abre **SQL Editor** y haz clic en **New query**.
3. Abre el archivo `schema.sql`, copia **todo** el contenido, pégalo ahí y haz clic en **Run**. Debe decir *Success. No rows returned*.
   - Si sale un error que dice *already exists*, ya lo corriste antes. No lo corras dos veces.
4. **Quitar la confirmación por email** (recomendado para que no se compliquen):
   menú izquierdo **Authentication** → **Sign In / Providers** → **Email** → apaga **Confirm email** → **Save**.
5. **Copiar tus dos claves:** haz clic en el botón **Connect** arriba (o ve a **Project Settings → API**). Copia:
   - **Project URL** (se ve así: `https://abcdxyz.supabase.co`)
   - **anon public key** o **publishable key** (una clave larga)

   Esta clave es segura de poner en la app: las reglas de seguridad del `schema.sql` protegen los datos de cada uno.

## Paso 2: Poner las claves en la app

1. Abre `index.html` con el Bloc de notas (Windows) o TextEdit (Mac). En TextEdit, ve a **Formato → Convertir a texto sin formato** primero.
2. Busca estas dos líneas (cerca del final, donde dice `STEP 1 OF SETUP`):
   ```
   const SUPABASE_URL = 'PASTE_YOUR_PROJECT_URL_HERE';
   const SUPABASE_KEY = 'PASTE_YOUR_ANON_OR_PUBLISHABLE_KEY_HERE';
   ```
3. Reemplaza el texto entre las comillas con tus valores. **Deja las comillas.** Debe quedar así:
   ```
   const SUPABASE_URL = 'https://abcdxyz.supabase.co';
   const SUPABASE_KEY = 'eyJhbGciOi...';
   ```
4. Guarda el archivo.

## Paso 3: Subirlo a GitHub

1. En [github.com](https://github.com), haz clic en **+** (arriba a la derecha) → **New repository**.
2. Nombre: `nexo-finances`. Puedes elegir **Private**. Haz clic en **Create repository**.
3. En la página que aparece, haz clic en el enlace **uploading an existing file**.
4. Arrastra `index.html` (y si quieres, `schema.sql` y esta guía). Abajo, haz clic en **Commit changes**.

## Paso 4: Publicarlo en Vercel

1. En [vercel.com](https://vercel.com), haz clic en **Add New… → Project**.
2. Busca `nexo-finances` en la lista y haz clic en **Import**. Si no aparece, haz clic en **Adjust GitHub App Permissions** y dale acceso a ese repositorio.
3. En **Framework Preset**, elige **Other**. No cambies nada más.
4. Haz clic en **Deploy**. En menos de un minuto te da un enlace como `nexo-finances-xyz.vercel.app`. Esa es tu app.

## Paso 5: Ponerla en los teléfonos

Abre el enlace de Vercel en cada teléfono:

- **iPhone:** en **Safari**, toca el botón de compartir (cuadro con flecha) → **Agregar a pantalla de inicio**.
- **Android:** en **Chrome**, toca los tres puntos → **Agregar a pantalla principal** o **Instalar app**.

Queda como un ícono más, igual que cualquier app.

## Paso 6: Primer uso

1. **Cada uno** crea su propia cuenta en la app (**Create account**) con su email.
2. **Uno de los dos** va al tab **Household** → **Create household**. Aparece un código de 6 letras.
3. **El otro** va a **Household** → **Join with a code** y pone ese código.
4. Cada uno agrega sus facturas en **Bills**. Para las que pagan tarde, pongan:
   - **Late fee:** el recargo (por ejemplo, lo que les cobran por pagar la casa después del 15).
   - **Autopay discount:** lo que se ahorran al mes con pago automático, si aplica.
   - **Money needed to catch up:** cuánto necesitan de golpe para ponerla al día o activar el pago automático.
5. En **Plan**, pongan cuánto pueden apartar al mes. La app les dice en qué orden arreglar cada factura y en qué mes, usando lo que se ahorran de cada una para arreglar la siguiente más rápido.

## Qué hace cada tab

- **Me:** lo que gastaste este mes, las facturas por pagar y cuándo vencen. Botón **Add expense** para anotar gastos.
- **Bills:** tus facturas, cuánto te cuestan en recargos y descuentos perdidos.
- **Plan:** el plan para ponerse al día paso a paso.
- **Household:** cuánto puso cada uno en cada categoría. Solo cuenta los gastos con **Count it in Household** activado. Los que apagues son privados.
- **Loans:** préstamos entre ustedes. Solo quien prestó puede anotar abonos, editar o borrar. El otro solo lo ve.

## Cómo hacer cambios después

En GitHub, abre `index.html`, toca el ícono del lápiz, haz el cambio y **Commit changes**. Vercel actualiza la app solo en un minuto.

## Si algo falla

- **"Almost there":** faltan las claves del Paso 2, o se borraron las comillas.
- **"Couldn't load" / "relation does not exist":** no se corrió el `schema.sql`, o se corrió en otro proyecto de Supabase.
- **"Invalid login credentials":** email o contraseña incorrectos. Si no apagaste *Confirm email*, primero confirma desde tu correo.
- **"That invite code does not exist":** revisa las 6 letras del código en el tab Household de tu pareja.
- Para cualquier otro error, copia el mensaje exacto y me lo pegas.
