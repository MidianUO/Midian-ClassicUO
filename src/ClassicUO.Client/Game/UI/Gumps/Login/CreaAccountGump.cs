// SPDX-License-Identifier: BSD-2-Clause

using ClassicUO.Game.Scenes;
using ClassicUO.Game.UI.Controls;
using ClassicUO.Input;
using ClassicUO.Assets;

namespace ClassicUO.Game.UI.Gumps.Login
{
    // Midian: creazione di un nuovo account dalla schermata di accesso. Il controllo dei nomi uguali o simili
    // lo fa il server (CClient::Login_CreaAccount in Midian-Sphere), che ha l'elenco degli account.
    internal sealed class CreaAccountGump : Gump
    {
        private const int BOTTONE_CREA = 1, BOTTONE_ANNULLA = 2;

        private readonly StbTextBox _nome;
        private readonly LoginGump.PasswordStbTextBox _password, _ripeti;
        private readonly Label _errore;

        public CreaAccountGump(World world, string nome) : base(world, 0, 0)
        {
            CanCloseWithRightClick = false;
            AcceptKeyboardInput = false;

            const int X = 150, Y = 110, L = 340, H = 290;

            Add(new ResizePic(0x0A28) { X = X, Y = Y, Width = L, Height = H });
            Add(new Label("Crea un nuovo account", false, 0x0386, L - 20, 2, align: TEXT_ALIGN_TYPE.TS_CENTER) { X = X + 10, Y = Y + 22 });

            int riga = Y + 55;

            _nome = Campo(ref riga, X, "Nome dell'account", new StbTextBox(5, 16, 190, false, hue: 0x034F));
            _password = (LoginGump.PasswordStbTextBox) Campo(ref riga, X, "Password", new LoginGump.PasswordStbTextBox(5, 16, 190, false, hue: 0x034F));
            _ripeti = (LoginGump.PasswordStbTextBox) Campo(ref riga, X, "Ripeti la password", new LoginGump.PasswordStbTextBox(5, 16, 190, false, hue: 0x034F));

            Add(_errore = new Label("", false, 0x0021, L - 40, 1, align: TEXT_ALIGN_TYPE.TS_CENTER) { X = X + 20, Y = riga + 2 });

            Add(new NiceButton(X + 40, Y + H - 40, 120, 24, ButtonAction.Activate, "Crea", align: TEXT_ALIGN_TYPE.TS_CENTER, hue: 0x0044) { ButtonParameter = BOTTONE_CREA, IsSelectable = false });
            Add(new NiceButton(X + L - 160, Y + H - 40, 120, 24, ButtonAction.Activate, "Annulla", align: TEXT_ALIGN_TYPE.TS_CENTER) { ButtonParameter = BOTTONE_ANNULLA, IsSelectable = false });

            _nome.SetText(nome ?? "");
            _nome.SetKeyboardFocus();
        }

        private T Campo<T>(ref int riga, int x, string testo, T campo) where T : Control
        {
            Add(new Label(testo, false, 0x0386, font: 1) { X = x + 65, Y = riga });
            Add(new ResizePic(0x0BB8) { X = x + 60, Y = riga + 16, Width = 220, Height = 28 });

            campo.X = x + 67;
            campo.Y = riga + 18;
            campo.Width = 205;
            campo.Height = 24;
            Add(campo);

            riga += 50;

            return campo;
        }

        public override void OnButtonClick(int buttonID)
        {
            if (buttonID == BOTTONE_CREA)
            {
                Crea();
            }
            else if (buttonID == BOTTONE_ANNULLA)
            {
                Dispose();
            }
        }

        public override void OnKeyboardReturn(int textID, string text)
        {
            Crea();
        }

        private void Crea()
        {
            string nome = _nome.Text.Trim();

            // Gli stessi controlli del server, per rispondere subito.
            if (nome.Length < 3)
            {
                _errore.Text = "Il nome deve avere almeno 3 caratteri.";
            }
            else if (_password.RealText.Length < 4)
            {
                _errore.Text = "La password deve avere almeno 4 caratteri.";
            }
            else if (_password.RealText != _ripeti.RealText)
            {
                _errore.Text = "Le due password non sono uguali.";
            }
            else
            {
                LoginScene scene = Client.Game.GetScene<LoginScene>();
                Dispose();
                scene.CreaAccount(nome, _password.RealText, false);
            }
        }
    }
}
