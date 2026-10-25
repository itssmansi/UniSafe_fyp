import { Webhook } from "https://esm.sh/standardwebhooks@1.0.0";
import { Resend } from "npm:resend@6";

const resend = new Resend(
  Deno.env.get("RESEND_API_KEY") as string
);

const hookSecret = (
  Deno.env.get("SEND_EMAIL_HOOK_SECRET") as string
).replace("v1,whsec_Q59S7t7yMsedZh1OG28zAhFUGwA9XnDdCGl3/hAR/D5EMrTzxHrDTMDrT41uBImVwsmXAqcNYs1aW21X", "");

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({
        error: "Method not allowed",
      }),
      {
        status: 405,
        headers: {
          "Content-Type": "application/json",
        },
      }
    );
  }

  try {
    const payload = await req.text();

    const headers = Object.fromEntries(req.headers);

    const wh = new Webhook(hookSecret);

    const {
      user,
      email_data,
    } = wh.verify(payload, headers) as {
      user: {
        email: string;
      };
      email_data: {
        token: string;
      };
    };

    const email = user.email;
    const otp = email_data.token;

    console.log("Sending UniSafe OTP to:", email);

    const { data, error } = await resend.emails.send({
      from: "UniSafe <onboarding@resend.dev>",
      to: [email],
      subject: "Your UniSafe Email Verification OTP",
      html: `
        <!DOCTYPE html>
        <html>
          <body
            style="
              font-family: Arial, sans-serif;
              background-color: #f7f7f7;
              padding: 30px;
            "
          >
            <div
              style="
                max-width: 500px;
                margin: auto;
                background: white;
                padding: 30px;
                border-radius: 12px;
              "
            >
              <h2 style="text-align: center;">
                UniSafe Email Verification
              </h2>

              <p>Hello,</p>

              <p>
                Use the following OTP to verify your email address
                during UniSafe registration:
              </p>

              <div
                style="
                  text-align: center;
                  margin: 30px 0;
                  font-size: 36px;
                  font-weight: bold;
                  letter-spacing: 8px;
                "
              >
                ${otp}
              </div>

              <p>
                This OTP is valid for a limited time and can only
                be used once.
              </p>

              <p>
                If you did not request this verification code,
                you can safely ignore this email.
              </p>

              <hr />

              <p
                style="
                  font-size: 12px;
                  color: #777;
                  text-align: center;
                "
              >
                UniSafe — Community Safety Platform
              </p>
            </div>
          </body>
        </html>
      `,
    });

    if (error) {
      console.error("Resend error:", error);

      return new Response(
        JSON.stringify({
          error: error.message,
        }),
        {
          status: 500,
          headers: {
            "Content-Type": "application/json",
          },
        }
      );
    }

    console.log("Email sent successfully:", data);

    return new Response(
      JSON.stringify({}),
      {
        status: 200,
        headers: {
          "Content-Type": "application/json",
        },
      }
    );
  } catch (error) {
    console.error("Send Email Hook error:", error);

    return new Response(
      JSON.stringify({
        error: "Failed to send authentication email.",
      }),
      {
        status: 401,
        headers: {
          "Content-Type": "application/json",
        },
      }
    );
  }
});