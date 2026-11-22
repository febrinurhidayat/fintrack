import { createClient } from "@supabase/supabase-js";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const jsonResponse = (
    body: Record<string, unknown>,
    status: number,
  ) => {
    return new Response(JSON.stringify(body), {
      status,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
      },
    });
  };

  try {
    if (req.method !== "POST") {
      return jsonResponse({ error: "Method tidak diizinkan." }, 405);
    }

    const authorization = req.headers.get("Authorization");

    if (!authorization?.startsWith("Bearer ")) {
      return jsonResponse({ error: "Sesi tidak ditemukan." }, 401);
    }

    const body = await req.json();
    const password = body.password;

    if (typeof password !== "string" || password.length === 0) {
      return jsonResponse({ error: "Password wajib diisi." }, 400);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const accessToken = authorization.substring(7);

    const adminClient = createClient(
      supabaseUrl,
      serviceRoleKey,
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      },
    );

    // Verifikasi sesi pengguna.
    const {
      data: { user },
      error: userError,
    } = await adminClient.auth.getUser(accessToken);

    if (userError || !user || !user.email) {
      return jsonResponse(
        { error: "Sesi pengguna tidak valid." },
        401,
      );
    }

    // Verifikasi password akun.
    const authClient = createClient(
      supabaseUrl,
      anonKey,
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      },
    );

    const { error: passwordError } =
      await authClient.auth.signInWithPassword({
        email: user.email,
        password,
      });

    if (passwordError) {
      return jsonResponse(
        { error: "Password yang dimasukkan salah." },
        401,
      );
    }

    // Hapus foto profil dari Storage.
    const { data: profile } = await adminClient
      .from("profiles")
      .select("avatar_url")
      .eq("id", user.id)
      .maybeSingle();

    if (profile?.avatar_url) {
      const marker = "/storage/v1/object/public/avatars/";
      const avatarUrl = profile.avatar_url as string;

      const markerIndex = avatarUrl.indexOf(marker);

      if (markerIndex !== -1) {
        const avatarPath = decodeURIComponent(
          avatarUrl.substring(markerIndex + marker.length),
        );

        // Pastikan file berada di folder milik pengguna.
        if (avatarPath.startsWith(`${user.id}/`)) {
          const { error: storageError } = await adminClient.storage
            .from("avatars")
            .remove([avatarPath]);

          if (storageError) {
            console.error("Gagal menghapus foto profil:", storageError);

            return jsonResponse(
              { error: "Gagal menghapus foto profil." },
              500,
            );
          }
        }
      }
    }

    // Hapus data milik pengguna secara berurutan.
    const deletionSteps = [
      { table: "transactions", column: "user_id" },
      { table: "transfers", column: "user_id" },
      { table: "account_balances", column: "user_id" },
      { table: "accounts", column: "user_id" },
      { table: "categories", column: "user_id" },
      { table: "profiles", column: "id" },
    ];

    for (const step of deletionSteps) {
      const { error } = await adminClient
        .from(step.table)
        .delete()
        .eq(step.column, user.id);

      if (error) {
        console.error(
          `Gagal menghapus ${step.table}:`,
          error,
        );

        return jsonResponse(
          {
            error: `Gagal menghapus data ${step.table}. Akun belum dihapus.`,
          },
          500,
        );
      }
    }

    // Hapus akun autentikasi setelah data terkait berhasil dibersihkan.
    const { error: deleteError } =
      await adminClient.auth.admin.deleteUser(user.id);

    if (deleteError) {
      console.error("Delete account error:", deleteError);

      return jsonResponse(
        { error: "Gagal menghapus akun autentikasi." },
        500,
      );
    }

    return jsonResponse(
      { message: "Akun dan data berhasil dihapus." },
      200,
    );
  } catch (error) {
    console.error("Unexpected error:", error);

    return jsonResponse(
      { error: "Terjadi kesalahan pada server." },
      500,
    );
  }
});
