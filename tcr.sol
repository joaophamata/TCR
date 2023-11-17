// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract SistemaDeRevisaoDeCodigo is ERC20 {
    using SafeMath for uint256;

    struct Codigo {
        address autor;
        uint256 complexidade;
        string conteudoCodigo;
        uint256 horarioInicio;
        uint256 tempoVotacao;
        bool estaAberto;
        bool foiAceito;
        uint256 likes;
        uint256 dislikes;
        uint256 objecoes;
    }

    struct Objecao {
        address objetor;
        uint256 indiceCodigo;
        string conteudoObjecao;
        uint256 horarioInicio;
        uint256 tempoVotacao;
        bool estaAberta;
        bool foiAceita;
        uint256 likes;
        uint256 dislikes;
        uint8 fase; // Atributo para rastrear a trajetória da objeção
    }

    enum Fase { Inicializando, Votacao, VotacaoObjecoes, VotacaoFinal, Encerrado }

    Fase public faseAtual;
    uint256 public indiceGrupoAtual;
    uint256 public tamanhoGrupo;
    uint256 public limiteTempo;

    uint256 public limiteConfianca;
    uint256 public minVotos;

    Codigo[] public codigos;
    Objecao[] public objecoes;
    mapping(uint256 => uint8) public trajetoriaObjecao;

    address[] public grupoA;
    address[] public grupoB;
    address[] public grupoC;

    mapping(address => bool) public jaVotou;

    address public enderecoToken;

    uint256 public pagamentoInicial;
    uint256 public taxaObjecao;
    uint256 public taxaVoto;

    mapping(address => bool) public emitiuObjecao;

    event CodigoFinalizado(bool foiAceito);
    event FaseAlterada(Fase fase);

    constructor(
        uint256 _tamanhoGrupo,
        uint256 _limiteTempo,
        uint256 _limiteConfianca,
        uint256 _minVotos,
        uint256 _pagamentoInicial,
        uint256 _taxaObjecao,
        uint256 _taxaVoto,
        address _enderecoToken
    ) ERC20("TokenRevisaoCodigo", "TRC") {
        tamanhoGrupo = _tamanhoGrupo;
        limiteTempo = _limiteTempo;
        limiteConfianca = _limiteConfianca;
        minVotos = _minVotos;
        faseAtual = Fase.Inicializando;
        indiceGrupoAtual = 0;
        pagamentoInicial = _pagamentoInicial;
        taxaObjecao = _taxaObjecao;
        taxaVoto = _taxaVoto;
        enderecoToken = _enderecoToken;

        _mint(msg.sender, _pagamentoInicial);
    }

    modifier apenasDuranteFase(Fase _fase) {
        require(faseAtual == _fase, "Fase invalida");
        _;
    }

    modifier naoVotou() {
        require(!jaVotou[msg.sender], "Voce ja votou");
        _;
    }

    modifier temSuficientesTokens(uint256 quantidade) {
        require(balanceOf(msg.sender) >= quantidade, "Saldo de tokens insuficiente");
        _;
    }

    function resetarVotos() internal returns (mapping(address => bool) memory) {
        for (uint256 i = 0; i < tamanhoGrupo; i++) {
            jaVotou[codigos[indiceGrupoAtual * tamanhoGrupo + i].autor] = false;
        }
        return jaVotou;
    }

    function inicializarCodigo(uint256 _complexidade, string memory _conteudo) external apenasDuranteFase(Fase.Inicializando) {
        require(balanceOf(msg.sender) >= pagamentoInicial, "Saldo insuficiente para pagamento inicial");
        _transfer(msg.sender, address(this), pagamentoInicial);

        codigos.push(Codigo({
            autor: msg.sender,
            complexidade: _complexidade,
            conteudoCodigo: _conteudo,
            horarioInicio: block.timestamp,
            tempoVotacao: block.timestamp + limiteTempo,
            estaAberto: true,
            foiAceito: false,
            likes: 0,
            dislikes: 0,
            objecoes: 0
        }));

        faseAtual = Fase.Votacao;
        emit FaseAlterada(faseAtual);
    }

    function votarCodigo(bool _gostou) external apenasDuranteFase(Fase.Votacao) naoVotou temSuficientesTokens(taxaVoto) {
        uint256 indiceCodigo = indiceGrupoAtual * tamanhoGrupo + jaVotou[msg.sender];
        jaVotou[msg.sender] = true;

        if (_gostou) {
            codigos[indiceCodigo].likes++;
        } else {
            codigos[indiceCodigo].dislikes++;
        }

        if (block.timestamp >= codigos[indiceCodigo].tempoVotacao) {
            encerrarFaseVotacao();
        }
    }

    function levantarObjecao(uint256 _indiceCodigo, string memory _conteudoObjecao) 
        external 
        apenasDuranteFase(Fase.VotacaoObjecoes) 
        naoVotou 
        temSuficientesTokens(taxaObjecao) 
    {
        require(_indiceCodigo < codigos.length, "Indice de codigo invalido");
        require(!codigos[_indiceCodigo].estaAberto, "O codigo ainda esta aberto para votacao");
        require(!emitiuObjecao[msg.sender], "Ja emitiu uma objecao");

        objecoes.push(Objecao({
            objetor: msg.sender,
            indiceCodigo: _indiceCodigo,
            conteudoObjecao: _conteudoObjecao,
            horarioInicio: block.timestamp,
            tempoVotacao: block.timestamp + limiteTempo,
            estaAberta: true,
            foiAceita: false,
            likes: 0,
            dislikes: 0,
            fase: 1 // 1 representa a trajetória inicial na Fase 1
        }));

        emitiuObjecao[msg.sender] = true;

        emit ObjecaoSubmetida(objecoes.length - 1);

        if (objecoes.length % tamanhoGrupo == 0) {
            indiceGrupoAtual++;
        }

        if (block.timestamp >= objecoes[indiceGrupoAtual * tamanhoGrupo].tempoVotacao) {
            encerrarFaseVotacaoObjecoes();
        }
    }

    function votarObjecao(uint256 _indiceObjecao, bool _gostou) 
        external 
        apenasDuranteFase(Fase.VotacaoObjecoes) 
        naoVotou 
        temSuficientesTokens(taxaVoto) 
    {
        require(indiceGrupoAtual * tamanhoGrupo < objecoes.length, "Todas as objecoes foram votadas");

        uint256 indiceObjecao = indiceGrupoAtual * tamanhoGrupo + jaVotou[msg.sender];
        jaVotou[msg.sender] = true;

        if (_gostou) {
            objecoes[indiceObjecao].likes++;
        } else {
            objecoes[indiceObjecao].dislikes++;
        }

        if (block.timestamp >= objecoes[indiceObjecao].tempoVotacao) {
            encerrarFaseVotacaoObjecoes();
        }
    }

    function iniciarVotacaoFinal() external apenasDuranteFase(Fase.VotacaoFinal) {
        faseAtual = Fase.VotacaoFinal;
        emit FaseAlterada(faseAtual);
    }

    function votarObjecaoFinal(uint256 _indiceObjecao, bool _gostou) 
        external 
        apenasDuranteFase(Fase.VotacaoFinal) 
        naoVotou 
        temSuficientesTokens(taxaVoto) 
    {
        require(_indiceObjecao < objecoes.length, "Indice de objecao invalido");

        uint256 indiceObjecao = _indiceObjecao;
        jaVotou[msg.sender] = true;

        if (_gostou) {
            objecoes[indiceObjecao].likes++;
        } else {
            objecoes[indiceObjecao].dislikes++;
        }

        if (block.timestamp >= objecoes[indiceObjecao].tempoVotacao) {
            encerrarFaseVotacaoFinal();
        }
    }

    function encerrarFaseVotacao() internal {
        bool foiCodigoAceito = true;

        // Lógica para determinar se o código é aceito ou não com base nos votos
        for (uint256 i = 0; i < codigos.length; i++) {
            uint256 votosTotais = codigos[i].likes + codigos[i].dislikes;

            if (votosTotais < minVotos || codigos[i].likes.mul(100).div(votosTotais) < limiteConfianca) {
                foiCodigoAceito = false;
                break;
            }
        }

        if (foiCodigoAceito) {
            // Emitir recompensas aos eleitores
            distribuirRecompensas();
            emit CodigoFinalizado(true);
        } else {
            emit CodigoFinalizado(false);
        }

        faseAtual = Fase.Encerrado;
        emit FaseAlterada(faseAtual);
    }

    function encerrarFaseVotacaoObjecoes() internal {
        bool foramObjecoesAceitas = true;

        // Lógica para determinar se as objeções são aceitas ou não com base nos votos
        for (uint256 i = 0; i < objecoes.length; i++) {
            uint256 votosTotais = objecoes[i].likes + objecoes[i].dislikes;

            if (votosTotais < minVotos || objecoes[i].likes.mul(100).div(votosTotais) < limiteConfianca) {
                foramObjecoesAceitas = false;
                break;
            }
        }

        if (!foramObjecoesAceitas) {
            encerrarFaseVotacao();
        } else {
            indiceGrupoAtual = 0; // Reiniciar o índice do grupo para a Fase 2
        }
    }

    function encerrarFaseVotacaoFinal() internal {
        bool foramObjecoesAceitas = true;

        // Lógica para determinar se as objeções são aceitas ou não com base nos votos
        for (uint256 i = 0; i < objecoes.length; i++) {
            uint256 votosTotais = objecoes[i].likes + objecoes[i].dislikes;

            if (votosTotais < minVotos || objecoes[i].likes.mul(100).div(votosTotais) < limiteConfianca) {
                foramObjecoesAceitas = false;
                break;
            }
        }

        if (foramObjecoesAceitas) {
            // Emitir recompensas aos eleitores
            distribuirRecompensas();
            emit CodigoFinalizado(true);
        } else {
            emit CodigoFinalizado(false);
        }

        faseAtual = Fase.Encerrado;
        emit FaseAlterada(faseAtual);
    }

    function distribuirRecompensas() internal {
        //
    }
}
