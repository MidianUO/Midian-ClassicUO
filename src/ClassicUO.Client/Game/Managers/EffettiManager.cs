// SPDX-License-Identifier: BSD-2-Clause

// Midian: elenco degli effetti attivi mandato dal server di Midian (pacchetto 0xBF, sottocomando 0x4D45).
// Il client lo chiede con 0x12 tipo 0x4D "EFFETTI 1" (OutgoingPackets.Send_MidianEffetti) quando entra nel
// mondo; un server che non lo conosce lo ignora. Lo mostra EffettiGump.
//
// Formato: BYTE versione (1), WORD numero di voci, poi per ogni voce BYTE tipo (0 benefico, 1 dannoso,
// 2 abilita' o script, 3 passivo), DWORD secondi che mancano (0xFFFFFFFF = senza scadenza), BYTE lunghezza
// del nome, il nome (latin1).

using ClassicUO.IO;
using System.Collections.Generic;
using System.Text;

namespace ClassicUO.Game.Managers
{
    internal enum EffettoTipo : byte
    {
        Benefico = 0,
        Dannoso = 1,
        Script = 2,
        Passivo = 3
    }

    internal sealed class Effetto
    {
        public EffettoTipo Tipo;
        public uint Secondi;    // 0xFFFFFFFF = senza scadenza
        public string Nome;
    }

    internal static class EffettiManager
    {
        public const uint SENZA_SCADENZA = 0xFFFF_FFFF;

        public static readonly List<Effetto> Voci = new List<Effetto>();

        // Time.Ticks quando e' arrivato l'elenco: il conto alla rovescia si fa da qui.
        public static uint RicevutoTicks { get; private set; }

        // Cresce a ogni elenco ricevuto: la finestra ricostruisce le righe quando cambia.
        public static int Versione { get; private set; }

        // Il server ha risposto almeno una volta: sa mandare gli effetti.
        public static bool Supportato { get; private set; }

        private static readonly Encoding _latin1 = Encoding.Latin1;

        public static void Leggi(ref StackDataReader p)
        {
            if (p.Remaining < 3)
            {
                return;
            }

            byte versione = p.ReadUInt8();

            if (versione != 1)
            {
                return;
            }

            int n = p.ReadUInt16BE();
            Voci.Clear();

            for (int i = 0; i < n && p.Remaining >= 6; i++)
            {
                byte tipo = p.ReadUInt8();
                uint secondi = p.ReadUInt32BE();
                int len = p.ReadUInt8();

                if (len > p.Remaining)
                {
                    break;
                }

                byte[] nome = new byte[len];

                for (int k = 0; k < len; k++)
                {
                    nome[k] = p.ReadUInt8();
                }

                Voci.Add(new Effetto { Tipo = (EffettoTipo) tipo, Secondi = secondi, Nome = _latin1.GetString(nome) });
            }

            RicevutoTicks = Time.Ticks;
            Versione++;
            Supportato = true;
        }

        // Secondi che mancano adesso (contando il tempo passato dall'arrivo dell'elenco), oppure -1.
        public static int SecondiAdesso(Effetto e)
        {
            if (e.Secondi == SENZA_SCADENZA)
            {
                return -1;
            }

            long passati = (Time.Ticks - RicevutoTicks) / 1000;
            long resto = e.Secondi - passati;

            return resto < 0 ? 0 : (int) resto;
        }

        public static void Reset()
        {
            Voci.Clear();
            Versione++;
            Supportato = false;
        }
    }
}
