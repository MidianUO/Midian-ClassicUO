// SPDX-License-Identifier: BSD-2-Clause

// Midian (MidianUO/Midian-ClassicUO#11): icone delle abilita' dei libri di classe.
//
// I libri di classe di Midian (Necronomicon, Manuale dello stratega, Libro della natura...) sono pannelli del server
// con un pulsante per abilita'. Trascinando un pulsante fuori dal libro si crea un'icona che resta sullo schermo e si
// salva nel profilo, come le icone delle magie. Al clic l'icona fa da sola quello che farebbe il giocatore: doppio
// clic sul libro e, appena il server manda il pannello, risposta col pulsante dell'abilita', senza mostrare il
// pannello. Per il server non cambia niente: restano classe, attese, usura del libro e costi.

using System;
using System.Collections.Generic;
using System.Xml;
using ClassicUO.Assets;
using ClassicUO.Configuration;
using ClassicUO.Game.GameObjects;
using ClassicUO.Game.Managers;
using ClassicUO.Game.UI.Controls;
using ClassicUO.Input;
using ClassicUO.Network;
using ClassicUO.Renderer;

namespace ClassicUO.Game.UI.Gumps
{
    internal static class MidianAbilita
    {
        // I numeri dei pannelli [GUMP n] dei libri di classe (SPHEREgump2.SCP di Midian-Script).
        private static readonly HashSet<uint> _libri = new HashSet<uint> { 59, 60, 61, 62, 63, 64, 71, 72, 73, 76, 77, 102 };

        // Pulsante 50 = "Guida alle abilita'": non e' un'abilita'.
        private const int PULSANTE_GUIDA = 50;

        // Quanto si aspetta il pannello dopo il doppio clic sul libro, in millisecondi.
        private const uint ATTESA_MS = 3000;

        // Pannello -> il libro (oggetto) che l'ha aperto l'ultima volta.
        private static readonly Dictionary<uint, uint> _libroPerPannello = new Dictionary<uint, uint>();

        private static uint _attesaPannello;
        private static int _attesaPulsante;
        private static uint _attesaFino;

        public static bool IsLibro(uint pannello)
        {
            return _libri.Contains(pannello);
        }

        public static bool PulsanteTrascinabile(uint pannello, Button b)
        {
            return IsLibro(pannello) && b.ButtonAction == ButtonAction.Activate && b.ButtonID > 0 && b.ButtonID != PULSANTE_GUIDA;
        }

        // Il server ha mandato il pannello di un libro: il libro e' l'ultimo oggetto su cui si e' fatto doppio clic.
        public static void PannelloAperto(World world, uint pannello)
        {
            if (IsLibro(pannello) && SerialHelper.IsItem(world.LastObject))
            {
                _libroPerPannello[pannello] = world.LastObject;
            }
        }

        public static uint LibroDi(uint pannello)
        {
            return _libroPerPannello.TryGetValue(pannello, out uint libro) ? libro : 0;
        }

        // Clic su un'icona: doppio clic sul libro, poi si aspetta il suo pannello.
        public static void Usa(World world, uint libro, uint pannello, int pulsante)
        {
            if (world == null || world.Player == null)
            {
                return;
            }

            if (libro == 0 || world.Items.Get(libro) == null)
            {
                GameActions.Print(world, "Il libro di questa abilita' non e' con te: apri il libro e trascina di nuovo il pulsante.", 33);

                return;
            }

            _attesaPannello = pannello;
            _attesaPulsante = pulsante;
            _attesaFino = Time.Ticks + ATTESA_MS;

            GameActions.DoubleClick(world, libro);
        }

        // Il pannello atteso e' arrivato: si risponde col pulsante dell'abilita' e non si mostra. Vero = gestito.
        public static bool RispostaAutomatica(uint mittente, uint pannello)
        {
            if (_attesaPannello == 0 || _attesaPannello != pannello)
            {
                return false;
            }

            bool inTempo = Time.Ticks <= _attesaFino;
            int pulsante = _attesaPulsante;
            _attesaPannello = 0;

            if (!inTempo)
            {
                return false;
            }

            GameActions.ReplyGump(mittente, pannello, pulsante, Array.Empty<uint>(), Array.Empty<Tuple<ushort, string>>());

            return true;
        }

        // Il nome dell'abilita': l'etichetta con del testo piu' vicina a uno dei pulsanti con lo stesso numero
        // (lo stesso pulsante compare spesso due volte: nell'indice e nella pagina dell'abilita').
        public static string NomeDelPulsante(Gump libro, int pulsante)
        {
            string nome = null;
            int migliore = int.MaxValue;

            foreach (Control c in libro.Children)
            {
                if (!(c is Button b) || b.ButtonAction != ButtonAction.Activate || b.ButtonID != pulsante)
                {
                    continue;
                }

                foreach (Control d in libro.Children)
                {
                    if (!(d is Label l) || l.Page != b.Page || string.IsNullOrWhiteSpace(l.Text))
                    {
                        continue;
                    }

                    string t = l.Text.Trim();
                    bool lettere = false;

                    foreach (char ch in t)
                    {
                        if (char.IsLetter(ch))
                        {
                            lettere = true;

                            break;
                        }
                    }

                    if (!lettere || t.StartsWith("Reagent", StringComparison.OrdinalIgnoreCase) || t.StartsWith("page", StringComparison.OrdinalIgnoreCase))
                    {
                        continue;
                    }

                    int punti = Math.Abs(l.Y - b.Y) * 3 + Math.Abs(l.X - b.X);

                    if (punti < migliore)
                    {
                        migliore = punti;
                        nome = t;
                    }
                }
            }

            return migliore <= 400 && nome != null ? nome : "Abilita' " + pulsante;
        }

        // Trascinamento iniziato sopra il pulsante di un'abilita': crea l'icona e la mette sotto il mouse.
        public static void CreaIcona(Gump libro, Button b)
        {
            uint pannello = libro.ServerSerial;
            uint oggetto = LibroDi(pannello);
            int pulsante = b.ButtonID;

            // Una sola icona per abilita'.
            for (LinkedListNode<Gump> i = UIManager.Gumps.Last; i != null; i = i.Previous)
            {
                if (i.Value is MidianAbilitaButtonGump g && g.Pannello == pannello && g.Pulsante == pulsante)
                {
                    g.Dispose();
                }
            }

            MidianAbilitaButtonGump icona = new MidianAbilitaButtonGump(libro.World, oggetto, pannello, pulsante, NomeDelPulsante(libro, pulsante), Mouse.LClickPosition.X - 44, Mouse.LClickPosition.Y - 22);

            UIManager.Add(icona);
            UIManager.AttemptDragControl(icona, true);
        }
    }

    internal class MidianAbilitaButtonGump : AnchorableGump
    {
        private uint _libro;
        private uint _pannello;
        private int _pulsante;
        private string _nome;

        public MidianAbilitaButtonGump(World world, uint libro, uint pannello, int pulsante, string nome, int x, int y) : this(world)
        {
            X = x;
            Y = y;
            _libro = libro;
            _pannello = pannello;
            _pulsante = pulsante;
            _nome = nome;

            BuildGump();
        }

        public MidianAbilitaButtonGump(World world) : base(world, 0, 0)
        {
            CanMove = true;
            AcceptMouseInput = true;
            CanCloseWithRightClick = true;
            WantUpdateSize = false;
            WidthMultiplier = 2;
            HeightMultiplier = 1;
            GroupMatrixWidth = 44;
            GroupMatrixHeight = 44;
            AnchorType = ANCHOR_TYPE.SPELL;
        }

        public override GumpType GumpType => GumpType.AbilitaLibro;

        public uint Pannello => _pannello;

        public int Pulsante => _pulsante;

        private void BuildGump()
        {
            Width = 88;
            Height = 44;

            Add
            (
                new ResizePic(0x24B8)
                {
                    Width = Width,
                    Height = Height,
                    AcceptMouseInput = true,
                    CanMove = true
                }
            );

            Label label;

            Add
            (
                label = new Label
                (
                    _nome,
                    true,
                    0,
                    Width - 8,
                    1,
                    FontStyle.None,
                    TEXT_ALIGN_TYPE.TS_CENTER
                )
                {
                    X = 4,
                    Y = 0,
                    Width = Width - 8,
                    AcceptMouseInput = true,
                    CanMove = true
                }
            );

            label.Y = (Height >> 1) - (label.Height >> 1);
        }

        protected override void OnMouseUp(int x, int y, MouseButtonType button)
        {
            base.OnMouseUp(x, y, button);

            if (ProfileManager.CurrentProfile.CastSpellsByOneClick && button == MouseButtonType.Left && !Keyboard.Alt)
            {
                MidianAbilita.Usa(World, _libro, _pannello, _pulsante);
            }
        }

        protected override bool OnMouseDoubleClick(int x, int y, MouseButtonType button)
        {
            if (!ProfileManager.CurrentProfile.CastSpellsByOneClick && button == MouseButtonType.Left && !Keyboard.Alt)
            {
                MidianAbilita.Usa(World, _libro, _pannello, _pulsante);

                return true;
            }

            return false;
        }

        public override void Save(XmlTextWriter writer)
        {
            base.Save(writer);
            writer.WriteAttributeString("libro", _libro.ToString());
            writer.WriteAttributeString("pannello", _pannello.ToString());
            writer.WriteAttributeString("pulsante", _pulsante.ToString());
            writer.WriteAttributeString("nome", _nome ?? string.Empty);
        }

        public override void Restore(XmlElement xml)
        {
            base.Restore(xml);

            if (uint.TryParse(xml.GetAttribute("libro"), out _libro) &&
                uint.TryParse(xml.GetAttribute("pannello"), out _pannello) &&
                int.TryParse(xml.GetAttribute("pulsante"), out _pulsante) &&
                MidianAbilita.IsLibro(_pannello) && _pulsante > 0)
            {
                _nome = xml.GetAttribute("nome");

                if (string.IsNullOrEmpty(_nome))
                {
                    _nome = "Abilita' " + _pulsante;
                }

                BuildGump();
            }
            else
            {
                Dispose();
            }
        }
    }
}
