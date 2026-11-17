# « Cœurs » exportables : le réseau sans les transformées (STFT / iSTFT restent côté appelant, comme dans le produit).
import torch
from torch import nn
from einops import rearrange, pack, unpack


class BSCore(nn.Module):
    """BS-Roformer / Mel-Band Roformer : spectre (b, f·s, t, 2) réel → masque complexe (b, n, f·s, t, 2) réel.
    Reprend models/bs_roformer/bs_roformer.py forward, lignes entre la STFT et la multiplication par le masque."""

    def __init__(self, m, time_group=0):
        super().__init__()
        self.m = m
        self.time_group = time_group      # > 0 : attention dans le temps par groupes de bandes (borne la mémoire, même résultat)

    def forward(self, stft_repr):
        m = self.m
        x = rearrange(stft_repr, 'b f t c -> b t (f c)')
        x = m.band_split(x)
        store = [None] * len(m.layers)
        for i, block in enumerate(m.layers):
            if len(block) == 3:
                linear_transformer, time_transformer, freq_transformer = block
                x, ft_ps = pack([x], 'b * d')
                x = linear_transformer(x)
                x, = unpack(x, ft_ps, 'b * d')
            else:
                time_transformer, freq_transformer = block
            if m.skip_connection:
                for j in range(i): x = x + store[j]
            x = rearrange(x, 'b t f d -> b f t d')
            x, ps = pack([x], '* t d')
            if self.time_group:
                g = self.time_group
                x = torch.cat([time_transformer(x[i:i + g]) for i in range(0, x.shape[0], g)], dim=0)
            else:
                x = time_transformer(x)
            x, = unpack(x, ps, '* t d')
            x = rearrange(x, 'b f t d -> b t f d')
            x, ps = pack([x], '* f d')
            x = freq_transformer(x)
            x, = unpack(x, ps, '* f d')
            if m.skip_connection: store[i] = x
        x = m.final_norm(x)
        mask = torch.stack([fn(x) for fn in m.mask_estimators], dim=1)
        return rearrange(mask, 'b n t (f c) -> b n f t c', c=2)


class MDX23CCore(nn.Module):
    """MDX23C (TFC-TDF v3) : spectre (b, 4, dim_f, t) → (b, n·4, dim_f, t). Reprend TFC_TDF_net.forward sans STFT / iSTFT."""

    def __init__(self, m):
        super().__init__()
        self.m = m

    def forward(self, x):
        m = self.m
        mix = x = m.cac2cws(x)
        first_conv_out = x = m.first_conv(x)
        x = x.transpose(-1, -2)
        enc = []
        for block in m.encoder_blocks:
            x = block.tfc_tdf(x); enc.append(x); x = block.downscale(x)
        x = m.bottleneck_block(x)
        for block in m.decoder_blocks:
            x = block.upscale(x); x = torch.cat([x, enc.pop()], 1); x = block.tfc_tdf(x)
        x = x.transpose(-1, -2)
        x = x * first_conv_out
        x = m.final_conv(torch.cat([mix, x], 1))
        return m.cws2cac(x)
