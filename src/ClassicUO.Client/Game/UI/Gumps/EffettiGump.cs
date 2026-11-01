// SPDX-License-Identifier: BSD-2-Clause

// Midian: finestra "Effetti attivi". Mostra gli effetti che il server di Midian manda con 0xBF 0x4D45
// (EffettiManager): magie benefiche e dannose, abilita' di classe e oggetti delle script con il tempo che manca,
// e le passive dell'armatura. Si sposta e si ridimensiona col mouse (angolo in basso a destra), si chiude con la
// X o con il clic destro; posizione e dimensione restano nel profilo (gumps.xml). Si apre dalla pallina della
// finestra delle statistiche.

using ClassicUO.Game.Managers;
using ClassicUO.Game.UI.Controls;
using ClassicUO.Input;
using Microsoft.Xna.Framework;
using System.Collections.Generic;
using System.Xml;

namespace ClassicUO.Game.UI.Gumps
{
    internal class EffettiGump : ResizableGump
    {
        private const int BORDO = 4;
        private const int TITOLO = 24;
        private const int MIN_W = 180;
        private const int MIN_H = 80;
        private const int RIGA_SPAZIO = 2;

        private static int _lastW = 280, _lastH = 220;

        private readonly AlphaBlendControl _sfondo;
        private readonly Label _titolo;
        private readonly NiceButton _chiudi;
        private ScrollArea _area;
        private DataBox _box;
        private readonly List<KeyValuePair<Label, Effetto>> _righe = new List<KeyValuePair<Label, Effetto>>();
        private int _versione = -1;
        private int _larghezzaRighe = -1;
        private uint _ultimoConto;

        public EffettiGump(World world) : base(world, _lastW, _lastH, MIN_W, MIN_H, 0, 0)
        {
            CanMove = true;
            AcceptMouseInput = true;
            CanCloseWithRightClick = true;
            X = 120;
            Y = 120;

            _sfondo = new AlphaBlendControl(0.75f) { X = BORDO, Y = BORDO };
            Add(_sfondo);

            _titolo = new Label("Effetti attivi", true, 0x0481, 0, 1) { X = BORDO + 6, Y = BORDO + 3 };
            Add(_titolo);

            _chiudi = new NiceButton(0, BORDO + 2, 22, 18, ButtonAction.Activate, "X") { ButtonParameter = 1 };
            Add(_chiudi);

            OnResize();
        }

        public override GumpType GumpType => GumpType.Effetti;

        public override void OnButtonClick(int buttonID)
        {
            if (buttonID == 1)
            {
                Dispose();
            }
        }

        public override void OnResize()
        {
            base.OnResize();

            if (_sfondo == null)
            {
                return; // chiamato dal costruttore di ResizableGump prima dei controlli
            }

            _sfondo.Width = Width - BORDO * 2;
            _sfondo.Height = Height - BORDO * 2;
            _chiudi.X = Width - BORDO - _chiudi.Width - 4;
            _lastW = Width;
            _lastH = Height;

            // L'area a scorrimento si rifa' con la nuova dimensione.
            _area?.Dispose();
            _area = new ScrollArea(BORDO + 4, BORDO + TITOLO, Width - BORDO * 2 - 8, Height - BORDO * 2 - TITOLO - 4, true)
            {
                AcceptMouseInput = true
            };
            _box = new DataBox(0, 0, 1, 1) { WantUpdateSize = true };
            _area.Add(_box);
            Add(_area);
            _versione = -1; // righe da rifare
        }

        public override void Update()
        {
            base.Update();

            if (IsDisposed)
            {
                return;
            }

            if (_versione != EffettiManager.Versione || _larghezzaRighe != _area.Width)
            {
                Ricostruisci();
            }
            else if (Time.Ticks - _ultimoConto >= 250)
            {
                AggiornaTempi();
            }
        }

        private void Ricostruisci()
        {
            _versione = EffettiManager.Versione;
            _larghezzaRighe = _area.Width;
            _righe.Clear();

            for (int i = _box.Children.Count - 1; i >= 0; i--)
            {
                _box.Children[i].Dispose(); // Dispose toglie il controllo dalla lista: si va a ritroso
            }

            int larghezza = _area.Width - 18; // spazio per la barra di scorrimento
            int y = 0;

            if (EffettiManager.Voci.Count == 0)
            {
                string testo = EffettiManager.Supportato ? "Nessun effetto attivo." : "In attesa del server...";
                _box.Add(new Label(testo, true, 0x0386, larghezza, 1) { Y = 0 });
            }

            foreach (Effetto e in EffettiManager.Voci)
            {
                Label riga = new Label(Testo(e), true, Colore(e.Tipo), larghezza, 1) { Y = y };
                _box.Add(riga);
                _righe.Add(new KeyValuePair<Label, Effetto>(riga, e));
                y += riga.Height + RIGA_SPAZIO;
            }

            _box.WantUpdateSize = true;
            _ultimoConto = Time.Ticks;
        }

        private void AggiornaTempi()
        {
            _ultimoConto = Time.Ticks;

            foreach (KeyValuePair<Label, Effetto> r in _righe)
            {
                if (r.Value.Secondi == EffettiManager.SENZA_SCADENZA)
                {
                    continue;
                }

                string t = Testo(r.Value);

                if (r.Key.Text != t)
                {
                    r.Key.Text = t;
                }
            }
        }

        private static string Testo(Effetto e)
        {
            int s = EffettiManager.SecondiAdesso(e);

            if (s < 0)
            {
                return e.Nome;
            }

            string tempo = s >= 3600 ? $"{s / 3600}:{s / 60 % 60:00}:{s % 60:00}" : $"{s / 60}:{s % 60:00}";

            return $"{e.Nome}  {tempo}";
        }

        private static ushort Colore(EffettoTipo tipo)
        {
            switch (tipo)
            {
                case EffettoTipo.Benefico: return 0x0044; // verde
                case EffettoTipo.Dannoso: return 0x0021;  // rosso
                case EffettoTipo.Script: return 0x0035;   // giallo
                default: return 0x0386;                   // grigio chiaro (passive)
            }
        }

        public override void Save(XmlTextWriter writer)
        {
            base.Save(writer);
            writer.WriteAttributeString("rw", Width.ToString());
            writer.WriteAttributeString("rh", Height.ToString());
        }

        public override void Restore(XmlElement xml)
        {
            base.Restore(xml);

            Point dim = new Point(Width, Height);

            if (int.TryParse(xml.GetAttribute("rw"), out int w) && w > 0)
            {
                dim.X = w;
            }

            if (int.TryParse(xml.GetAttribute("rh"), out int h) && h > 0)
            {
                dim.Y = h;
            }

            ResizeWindow(dim);
        }

        // Apre la finestra, oppure la chiude se e' gia' aperta (pallina della finestra delle statistiche).
        public static void ApriChiudi(World world)
        {
            EffettiGump g = UIManager.GetGump<EffettiGump>();

            if (g != null)
            {
                g.Dispose();

                return;
            }

            UIManager.Add(new EffettiGump(world));
        }
    }
}
