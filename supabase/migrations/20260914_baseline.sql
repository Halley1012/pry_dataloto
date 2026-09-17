


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;




-- Name: actualizar_fecha_modificacion(); Type: FUNCTION; Schema: public; Owner: -
CREATE FUNCTION public.actualizar_fecha_modificacion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.fecha_actualizacion = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;
SET default_tablespace = '';
SET default_table_access_method = heap;
-- Name: categorias; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.categorias (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    slug character varying(150),
    icono character varying(100),
    activa boolean DEFAULT true NOT NULL,
    orden integer DEFAULT 0 NOT NULL,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    fecha_actualizacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);
-- Name: categorias_id_seq; Type: SEQUENCE; Schema: public; Owner: -
CREATE SEQUENCE public.categorias_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
-- Name: categorias_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
ALTER SEQUENCE public.categorias_id_seq OWNED BY public.categorias.id;
-- Name: ciudades; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.ciudades (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    departamento_id integer NOT NULL
);
-- Name: ciudades_id_seq; Type: SEQUENCE; Schema: public; Owner: -
CREATE SEQUENCE public.ciudades_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
-- Name: ciudades_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
ALTER SEQUENCE public.ciudades_id_seq OWNED BY public.ciudades.id;
-- Name: comments; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.comments (
    id integer NOT NULL,
    post_id integer NOT NULL,
    user_id integer NOT NULL,
    content character varying(300) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    status character varying(20) DEFAULT 'active'::character varying NOT NULL,
    moderation_reason character varying(50) DEFAULT NULL::character varying,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    parent_id integer,
    CONSTRAINT comments_content_length_check CHECK (((char_length(TRIM(BOTH FROM content)) >= 1) AND (char_length(TRIM(BOTH FROM content)) <= 300))),
    CONSTRAINT comments_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'pending'::character varying, 'rejected'::character varying, 'deleted'::character varying])::text[])))
);
-- Name: comments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
CREATE SEQUENCE public.comments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
-- Name: comments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
ALTER SEQUENCE public.comments_id_seq OWNED BY public.comments.id;
-- Name: departamentos; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.departamentos (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    pais_id integer
);
-- Name: departamentos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
CREATE SEQUENCE public.departamentos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
-- Name: departamentos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
ALTER SEQUENCE public.departamentos_id_seq OWNED BY public.departamentos.id;
-- Name: email_verification_codes; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.email_verification_codes (
    id integer NOT NULL,
    user_id integer NOT NULL,
    code character varying(10) NOT NULL,
    expires timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);
-- Name: email_verification_codes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
CREATE SEQUENCE public.email_verification_codes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
-- Name: email_verification_codes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
ALTER SEQUENCE public.email_verification_codes_id_seq OWNED BY public.email_verification_codes.id;
-- Name: jugadas; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.jugadas (
    id integer NOT NULL,
    user_id integer NOT NULL,
    loteria_route character varying(50) NOT NULL,
    numeros integer[] NOT NULL,
    fecha_sorteo date NOT NULL,
    fecha_guardado timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    expira timestamp with time zone,
    loteria_id integer
);
-- Name: jugadas_id_seq; Type: SEQUENCE; Schema: public; Owner: -
CREATE SEQUENCE public.jugadas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
-- Name: jugadas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
ALTER SEQUENCE public.jugadas_id_seq OWNED BY public.jugadas.id;
-- Name: loterias; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.loterias (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    tipo character varying(50),
    pais_id integer NOT NULL,
    activa boolean DEFAULT true,
    route character varying(50),
    max_seleccion integer DEFAULT 5,
    max_balotas_blancas integer DEFAULT 45,
    max_balotas_rojas integer DEFAULT 0,
    superbalota_nombre character varying(50) DEFAULT NULL::character varying,
    has_revancha boolean DEFAULT false,
    total_balotas_sorteo integer DEFAULT 5,
    tiene_complementario boolean DEFAULT false,
    tiene_reintegro boolean DEFAULT false
);
-- Name: loterias_id_seq; Type: SEQUENCE; Schema: public; Owner: -
CREATE SEQUENCE public.loterias_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
-- Name: loterias_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
ALTER SEQUENCE public.loterias_id_seq OWNED BY public.loterias.id;
-- Name: loterias_jackpots; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.loterias_jackpots (
    loteria character varying(50) NOT NULL,
    fecha date NOT NULL,
    jackpot character varying(100) NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);
-- Name: notificaciones; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.notificaciones (
    id integer NOT NULL,
    usuario_id integer,
    loteria_id integer,
    fecha_sorteo date,
    mensaje text,
    tipo character varying(50),
    leido boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);
-- Name: notificaciones_id_seq; Type: SEQUENCE; Schema: public; Owner: -
CREATE SEQUENCE public.notificaciones_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
-- Name: notificaciones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
ALTER SEQUENCE public.notificaciones_id_seq OWNED BY public.notificaciones.id;
-- Name: notification_user_state; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.notification_user_state (
    notification_id integer NOT NULL,
    user_id integer NOT NULL,
    leido boolean DEFAULT false NOT NULL,
    eliminado boolean DEFAULT false NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);
-- Name: paises; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.paises (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    codigo_iso character varying(5)
);
-- Name: paises_id_seq; Type: SEQUENCE; Schema: public; Owner: -
CREATE SEQUENCE public.paises_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
-- Name: paises_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
ALTER SEQUENCE public.paises_id_seq OWNED BY public.paises.id;
-- Name: password_reset_tokens; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.password_reset_tokens (
    id integer NOT NULL,
    user_id integer,
    token text NOT NULL,
    expires timestamp without time zone NOT NULL
);
-- Name: password_reset_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
CREATE SEQUENCE public.password_reset_tokens_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
-- Name: password_reset_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
ALTER SEQUENCE public.password_reset_tokens_id_seq OWNED BY public.password_reset_tokens.id;
-- Name: posts; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.posts (
    id integer NOT NULL,
    title text NOT NULL,
    content text NOT NULL,
    user_id integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);
-- Name: posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
CREATE SEQUENCE public.posts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
-- Name: posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
ALTER SEQUENCE public.posts_id_seq OWNED BY public.posts.id;
-- Name: predicciones; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.predicciones (
    id integer NOT NULL,
    loteria_id integer,
    loteria_route character varying(50) NOT NULL,
    fecha date NOT NULL,
    numeros integer[] NOT NULL,
    balotaroja integer[],
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);
-- Name: predicciones_colorloto2; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.predicciones_colorloto2 (
    id integer NOT NULL,
    fecha date NOT NULL,
    ranking text,
    created_at timestamp without time zone DEFAULT now()
);
-- Name: predicciones_colorloto2_id_seq; Type: SEQUENCE; Schema: public; Owner: -
CREATE SEQUENCE public.predicciones_colorloto2_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
-- Name: predicciones_colorloto2_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
ALTER SEQUENCE public.predicciones_colorloto2_id_seq OWNED BY public.predicciones_colorloto2.id;
-- Name: predicciones_id_seq; Type: SEQUENCE; Schema: public; Owner: -
CREATE SEQUENCE public.predicciones_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
-- Name: predicciones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
ALTER SEQUENCE public.predicciones_id_seq OWNED BY public.predicciones.id;
-- Name: publicidad; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.publicidad (
    id integer NOT NULL,
    usuario_id integer NOT NULL,
    titulo character varying(200) NOT NULL,
    descripcion text,
    imagen_url character varying(500),
    categoria_id integer,
    telefono character varying(20),
    facebook_url character varying(255),
    instagram_url character varying(255),
    whatsapp_url character varying(255),
    tiktok_url character varying(255),
    pagina_url character varying(255),
    fecha_inicio date,
    fecha_fin date,
    estado boolean DEFAULT true,
    aprobado boolean DEFAULT false,
    pago_confirmado boolean DEFAULT false,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    direccion character varying,
    ciudad_id integer,
    pais_id integer,
    departamento_id integer,
    es_24_7 boolean DEFAULT true,
    hora_apertura character varying(10) DEFAULT '00:00'::character varying,
    hora_cierre character varying(10) DEFAULT '23:59'::character varying,
    dias_atencion character varying(50) DEFAULT 'Todos los días'::character varying,
    estado_texto character varying(50) DEFAULT 'Abierto 24/7'::character varying
);
-- Name: publicidad_calificaciones; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.publicidad_calificaciones (
    id integer NOT NULL,
    publicidad_id integer,
    user_id integer,
    estrellas integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT publicidad_calificaciones_estrellas_check CHECK (((estrellas >= 1) AND (estrellas <= 5)))
);
-- Name: publicidad_calificaciones_id_seq; Type: SEQUENCE; Schema: public; Owner: -
CREATE SEQUENCE public.publicidad_calificaciones_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
-- Name: publicidad_calificaciones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
ALTER SEQUENCE public.publicidad_calificaciones_id_seq OWNED BY public.publicidad_calificaciones.id;
-- Name: publicidad_id_seq; Type: SEQUENCE; Schema: public; Owner: -
CREATE SEQUENCE public.publicidad_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
-- Name: publicidad_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
ALTER SEQUENCE public.publicidad_id_seq OWNED BY public.publicidad.id;
-- Name: resultados_5deoro; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.resultados_5deoro (
    sorteo character varying(50),
    fecha date,
    balota1 integer,
    balota2 integer,
    balota3 integer,
    balota4 integer,
    balota5 integer,
    balotaroja integer,
    concurso integer,
    loteria_id integer,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);
-- Name: resultados_bloto; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.resultados_bloto (
    sorteo text,
    fecha date,
    balota1 bigint,
    balota2 bigint,
    balota3 bigint,
    balota4 bigint,
    balota5 bigint,
    balotaroja bigint,
    concurso integer,
    loteria_id integer,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);
-- Name: resultados_bonoloto; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.resultados_bonoloto (
    sorteo character varying(50),
    fecha date,
    balota1 integer,
    balota2 integer,
    balota3 integer,
    balota4 integer,
    balota5 integer,
    balota6 integer,
    balotaroja integer,
    balotaroja2 integer,
    loteria_id double precision,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    concurso double precision
);
-- Name: resultados_chispazo; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.resultados_chispazo (
    sorteo character varying(50),
    fecha date,
    balota1 integer,
    balota2 integer,
    balota3 integer,
    balota4 integer,
    balota5 integer,
    balotaroja integer,
    concurso double precision,
    loteria_id double precision,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
);
-- Name: resultados_colorloto; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.resultados_colorloto (
    fecha timestamp without time zone,
    amarillo bigint,
    azul bigint,
    rojo bigint,
    verde bigint,
    blanco bigint,
    negro bigint,
    loteria_id integer DEFAULT 6,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    concurso integer
);
-- Name: resultados_colorloto2; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.resultados_colorloto2 (
    fecha date,
    color text,
    numero bigint,
    loteria_id integer DEFAULT 6,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    concurso integer,
    posicion integer
);
-- Name: resultados_double_play; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.resultados_double_play (
    sorteo text,
    fecha date,
    balota1 bigint,
    balota2 bigint,
    balota3 bigint,
    balota4 bigint,
    balota5 bigint,
    balotaroja bigint,
    concurso integer,
    loteria_id integer,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);
-- Name: resultados_duplasena; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.resultados_duplasena (
    sorteo character varying(50),
    fecha date,
    balota1 integer,
    balota2 integer,
    balota3 integer,
    balota4 integer,
    balota5 integer,
    balota6 integer,
    balotaroja integer,
    concurso double precision,
    loteria_id double precision,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
);
-- Name: resultados_el_gordo; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.resultados_el_gordo (
    sorteo character varying(50),
    fecha date,
    balota1 integer,
    balota2 integer,
    balota3 integer,
    balota4 integer,
    balota5 integer,
    balotaroja integer,
    loteria_id double precision,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    concurso double precision
);
-- Name: resultados_eurodreams; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.resultados_eurodreams (
    sorteo character varying(50),
    fecha date,
    balota1 integer,
    balota2 integer,
    balota3 integer,
    balota4 integer,
    balota5 integer,
    balota6 integer,
    balotaroja integer,
    concurso double precision,
    loteria_id double precision,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
);
-- Name: resultados_eurojackpot; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.resultados_eurojackpot (
    concurso integer NOT NULL,
    loteria_id integer NOT NULL,
    sorteo character varying(50) NOT NULL,
    fecha date NOT NULL,
    balota1 integer NOT NULL,
    balota2 integer NOT NULL,
    balota3 integer NOT NULL,
    balota4 integer NOT NULL,
    balota5 integer NOT NULL,
    balotaroja integer DEFAULT 0 NOT NULL,
    balotaroja2 integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);
-- Name: resultados_euromillones; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.resultados_euromillones (
    sorteo character varying(50),
    fecha date,
    balota1 integer,
    balota2 integer,
    balota3 integer,
    balota4 integer,
    balota5 integer,
    balotaroja integer,
    balotaroja2 integer,
    loteria_id double precision,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    concurso double precision
);
-- Name: resultados_ganadiario; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.resultados_ganadiario (
    sorteo character varying(50),
    fecha date,
    balota1 integer,
    balota2 integer,
    balota3 integer,
    balota4 integer,
    balota5 integer,
    balotaroja integer,
    concurso double precision,
    loteria_id double precision,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
);
-- Name: resultados_kabala; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.resultados_kabala (
    sorteo character varying(50),
    fecha date,
    balota1 integer,
    balota2 integer,
    balota3 integer,
    balota4 integer,
    balota5 integer,
    balota6 integer,
    balotaroja integer,
    concurso double precision,
    loteria_id double precision,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
);
-- Name: resultados_latinka; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.resultados_latinka (
    sorteo character varying(50),
    fecha date,
    balota1 integer,
    balota2 integer,
    balota3 integer,
    balota4 integer,
    balota5 integer,
    balota6 integer,
    balotaroja integer,
    concurso double precision,
    loteria_id double precision,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
);
-- Name: resultados_lotto_6aus49; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.resultados_lotto_6aus49 (
    concurso integer NOT NULL,
    loteria_id integer NOT NULL,
    sorteo character varying(50) NOT NULL,
    fecha date NOT NULL,
    balota1 integer NOT NULL,
    balota2 integer NOT NULL,
    balota3 integer NOT NULL,
    balota4 integer NOT NULL,
    balota5 integer NOT NULL,
    balota6 integer NOT NULL,
    balotaroja integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);
-- Name: resultados_lotto_america; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.resultados_lotto_america (
    sorteo text,
    fecha date,
    balota1 bigint,
    balota2 bigint,
    balota3 bigint,
    balota4 bigint,
    balota5 bigint,
    balotaroja bigint,
    concurso integer,
    loteria_id integer,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);
-- Name: resultados_lotto_cr; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.resultados_lotto_cr (
    sorteo character varying(50),
    fecha date,
    balota1 integer,
    balota2 integer,
    balota3 integer,
    balota4 integer,
    balota5 integer,
    balotaroja integer
);
-- Name: resultados_lotto_fr; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.resultados_lotto_fr (
    sorteo character varying(50) NOT NULL,
    fecha date NOT NULL,
    balota1 integer,
    balota2 integer,
    balota3 integer,
    balota4 integer,
    balota5 integer,
    balotaroja integer,
    concurso integer NOT NULL,
    loteria_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);
-- Name: resultados_maismilionaria; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.resultados_maismilionaria (
    sorteo character varying(50),
    fecha date,
    balota1 integer,
    balota2 integer,
    balota3 integer,
    balota4 integer,
    balota5 integer,
    balota6 integer,
    balotaroja integer,
    balotaroja2 integer,
    concurso double precision,
    loteria_id double precision,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
);
-- Name: resultados_megamillions; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.resultados_megamillions (
    sorteo text,
    fecha date,
    balota1 bigint,
    balota2 bigint,
    balota3 bigint,
    balota4 bigint,
    balota5 bigint,
    balotaroja bigint,
    concurso integer,
    loteria_id integer,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);
-- Name: resultados_megasena; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.resultados_megasena (
    sorteo character varying(50),
    fecha date,
    balota1 integer,
    balota2 integer,
    balota3 integer,
    balota4 integer,
    balota5 integer,
    balota6 integer,
    concurso double precision,
    loteria_id double precision,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
);
-- Name: resultados_melate; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.resultados_melate (
    sorteo character varying(50),
    fecha date,
    balota1 integer,
    balota2 integer,
    balota3 integer,
    balota4 integer,
    balota5 integer,
    balota6 integer,
    balotaroja integer,
    concurso double precision,
    loteria_id double precision,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
);
-- Name: resultados_melateretro; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.resultados_melateretro (
    sorteo character varying(50),
    fecha date,
    balota1 integer,
    balota2 integer,
    balota3 integer,
    balota4 integer,
    balota5 integer,
    balota6 integer,
    balotaroja integer,
    concurso double precision,
    loteria_id double precision,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
);
-- Name: resultados_millionaire_life; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.resultados_millionaire_life (
    sorteo text,
    fecha date,
    balota1 bigint,
    balota2 bigint,
    balota3 bigint,
    balota4 bigint,
    balota5 bigint,
    balotaroja bigint,
    concurso integer,
    loteria_id integer,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);
-- Name: resultados_mloto; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.resultados_mloto (
    fecha date,
    balota1 bigint,
    balota2 bigint,
    balota3 bigint,
    balota4 bigint,
    balota5 bigint,
    concurso integer,
    loteria_id integer,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);
-- Name: resultados_powerball; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.resultados_powerball (
    sorteo text,
    fecha date,
    balota1 bigint,
    balota2 bigint,
    balota3 bigint,
    balota4 bigint,
    balota5 bigint,
    balotaroja bigint,
    concurso integer,
    loteria_id integer,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);
-- Name: resultados_primitiva; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.resultados_primitiva (
    sorteo character varying(50),
    fecha date,
    balota1 integer,
    balota2 integer,
    balota3 integer,
    balota4 integer,
    balota5 integer,
    balota6 integer,
    balotaroja integer,
    balotaroja2 integer,
    loteria_id double precision,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    concurso double precision
);
-- Name: resultados_quina; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.resultados_quina (
    sorteo character varying(50),
    fecha date,
    balota1 integer,
    balota2 integer,
    balota3 integer,
    balota4 integer,
    balota5 integer,
    balotaroja integer,
    concurso double precision,
    loteria_id double precision,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
);
-- Name: resultados_thunderball; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.resultados_thunderball (
    sorteo character varying(100) NOT NULL,
    fecha date NOT NULL,
    balota1 integer,
    balota2 integer,
    balota3 integer,
    balota4 integer,
    balota5 integer,
    balotaroja integer,
    concurso integer NOT NULL,
    loteria_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);
-- Name: resultados_totoloto; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.resultados_totoloto (
    sorteo character varying(50),
    fecha date NOT NULL,
    balota1 integer,
    balota2 integer,
    balota3 integer,
    balota4 integer,
    balota5 integer,
    balotaroja integer,
    concurso integer NOT NULL,
    loteria_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);
-- Name: transacciones; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.transacciones (
    id integer NOT NULL,
    referencia character varying(50) NOT NULL,
    nombre_cliente character varying(100),
    email_cliente character varying(100),
    monto numeric(12,2) NOT NULL,
    moneda character varying(10) NOT NULL,
    descripcion text,
    estado character varying(20) DEFAULT 'pendiente'::character varying,
    metodo_pago character varying(50),
    epayco_transaction_id character varying(100),
    respuesta_json jsonb,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);
-- Name: transacciones_id_seq; Type: SEQUENCE; Schema: public; Owner: -
CREATE SEQUENCE public.transacciones_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
-- Name: transacciones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
ALTER SEQUENCE public.transacciones_id_seq OWNED BY public.transacciones.id;
-- Name: user_subscriptions; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.user_subscriptions (
    id integer NOT NULL,
    user_id integer NOT NULL,
    product_id character varying(100) NOT NULL,
    purchase_token text,
    order_id character varying(255),
    status character varying(50) DEFAULT 'active'::character varying,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    expires_at timestamp with time zone
);
-- Name: user_subscriptions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
CREATE SEQUENCE public.user_subscriptions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
-- Name: user_subscriptions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
ALTER SEQUENCE public.user_subscriptions_id_seq OWNED BY public.user_subscriptions.id;
-- Name: user_subscriptions_replay_backup; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.user_subscriptions_replay_backup (
    id integer,
    user_id integer,
    product_id character varying(100),
    purchase_token text,
    order_id character varying(255),
    status character varying(50),
    created_at timestamp with time zone,
    expires_at timestamp with time zone
);
-- Name: users; Type: TABLE; Schema: public; Owner: -
CREATE TABLE public.users (
    id integer NOT NULL,
    name character varying(100),
    email character varying(100),
    password character varying(200),
    pais_id integer,
    departamento_id integer,
    created_at timestamp without time zone DEFAULT now(),
    fcm_token text,
    is_premium boolean DEFAULT false,
    premium_expires_at timestamp with time zone,
    google_order_id character varying(255),
    activo boolean DEFAULT true,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    last_login_at timestamp with time zone,
    rol character varying(20) DEFAULT 'user'::character varying,
    auth_provider character varying(30) DEFAULT 'email'::character varying,
    email_verified boolean DEFAULT false,
    avatar_url character varying(500),
    telefono character varying(30),
    idioma character varying(10) DEFAULT 'es'::character varying,
    notificaciones_activas boolean DEFAULT true,
    terms_accepted_at timestamp with time zone,
    app_version character varying(20),
    plataforma character varying(20),
    is_adult boolean DEFAULT true
);
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;
-- Name: categorias id; Type: DEFAULT; Schema: public; Owner: -
ALTER TABLE ONLY public.categorias ALTER COLUMN id SET DEFAULT nextval('public.categorias_id_seq'::regclass);
-- Name: ciudades id; Type: DEFAULT; Schema: public; Owner: -
ALTER TABLE ONLY public.ciudades ALTER COLUMN id SET DEFAULT nextval('public.ciudades_id_seq'::regclass);
-- Name: comments id; Type: DEFAULT; Schema: public; Owner: -
ALTER TABLE ONLY public.comments ALTER COLUMN id SET DEFAULT nextval('public.comments_id_seq'::regclass);
-- Name: departamentos id; Type: DEFAULT; Schema: public; Owner: -
ALTER TABLE ONLY public.departamentos ALTER COLUMN id SET DEFAULT nextval('public.departamentos_id_seq'::regclass);
-- Name: email_verification_codes id; Type: DEFAULT; Schema: public; Owner: -
ALTER TABLE ONLY public.email_verification_codes ALTER COLUMN id SET DEFAULT nextval('public.email_verification_codes_id_seq'::regclass);
-- Name: jugadas id; Type: DEFAULT; Schema: public; Owner: -
ALTER TABLE ONLY public.jugadas ALTER COLUMN id SET DEFAULT nextval('public.jugadas_id_seq'::regclass);
-- Name: loterias id; Type: DEFAULT; Schema: public; Owner: -
ALTER TABLE ONLY public.loterias ALTER COLUMN id SET DEFAULT nextval('public.loterias_id_seq'::regclass);
-- Name: notificaciones id; Type: DEFAULT; Schema: public; Owner: -
ALTER TABLE ONLY public.notificaciones ALTER COLUMN id SET DEFAULT nextval('public.notificaciones_id_seq'::regclass);
-- Name: paises id; Type: DEFAULT; Schema: public; Owner: -
ALTER TABLE ONLY public.paises ALTER COLUMN id SET DEFAULT nextval('public.paises_id_seq'::regclass);
-- Name: password_reset_tokens id; Type: DEFAULT; Schema: public; Owner: -
ALTER TABLE ONLY public.password_reset_tokens ALTER COLUMN id SET DEFAULT nextval('public.password_reset_tokens_id_seq'::regclass);
-- Name: posts id; Type: DEFAULT; Schema: public; Owner: -
ALTER TABLE ONLY public.posts ALTER COLUMN id SET DEFAULT nextval('public.posts_id_seq'::regclass);
-- Name: predicciones id; Type: DEFAULT; Schema: public; Owner: -
ALTER TABLE ONLY public.predicciones ALTER COLUMN id SET DEFAULT nextval('public.predicciones_id_seq'::regclass);
-- Name: predicciones_colorloto2 id; Type: DEFAULT; Schema: public; Owner: -
ALTER TABLE ONLY public.predicciones_colorloto2 ALTER COLUMN id SET DEFAULT nextval('public.predicciones_colorloto2_id_seq'::regclass);
-- Name: publicidad id; Type: DEFAULT; Schema: public; Owner: -
ALTER TABLE ONLY public.publicidad ALTER COLUMN id SET DEFAULT nextval('public.publicidad_id_seq'::regclass);
-- Name: publicidad_calificaciones id; Type: DEFAULT; Schema: public; Owner: -
ALTER TABLE ONLY public.publicidad_calificaciones ALTER COLUMN id SET DEFAULT nextval('public.publicidad_calificaciones_id_seq'::regclass);
-- Name: transacciones id; Type: DEFAULT; Schema: public; Owner: -
ALTER TABLE ONLY public.transacciones ALTER COLUMN id SET DEFAULT nextval('public.transacciones_id_seq'::regclass);
-- Name: user_subscriptions id; Type: DEFAULT; Schema: public; Owner: -
ALTER TABLE ONLY public.user_subscriptions ALTER COLUMN id SET DEFAULT nextval('public.user_subscriptions_id_seq'::regclass);
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);
-- Name: categorias categorias_nombre_key; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.categorias
    ADD CONSTRAINT categorias_nombre_key UNIQUE (nombre);
-- Name: categorias categorias_pkey; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.categorias
    ADD CONSTRAINT categorias_pkey PRIMARY KEY (id);
-- Name: ciudades ciudades_nombre_departamento_id_key; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.ciudades
    ADD CONSTRAINT ciudades_nombre_departamento_id_key UNIQUE (nombre, departamento_id);
-- Name: ciudades ciudades_pkey; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.ciudades
    ADD CONSTRAINT ciudades_pkey PRIMARY KEY (id);
-- Name: comments comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_pkey PRIMARY KEY (id);
-- Name: departamentos departamentos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.departamentos
    ADD CONSTRAINT departamentos_pkey PRIMARY KEY (id);
-- Name: email_verification_codes email_verification_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.email_verification_codes
    ADD CONSTRAINT email_verification_codes_pkey PRIMARY KEY (id);
-- Name: jugadas jugadas_pkey1; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.jugadas
    ADD CONSTRAINT jugadas_pkey1 PRIMARY KEY (id);
-- Name: loterias_jackpots loterias_jackpots_pkey; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.loterias_jackpots
    ADD CONSTRAINT loterias_jackpots_pkey PRIMARY KEY (loteria, fecha);
-- Name: loterias loterias_pkey; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.loterias
    ADD CONSTRAINT loterias_pkey PRIMARY KEY (id);
-- Name: notificaciones notificaciones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.notificaciones
    ADD CONSTRAINT notificaciones_pkey PRIMARY KEY (id);
-- Name: notification_user_state notification_user_state_pkey; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.notification_user_state
    ADD CONSTRAINT notification_user_state_pkey PRIMARY KEY (notification_id, user_id);
-- Name: paises paises_pkey; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.paises
    ADD CONSTRAINT paises_pkey PRIMARY KEY (id);
-- Name: password_reset_tokens password_reset_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.password_reset_tokens
    ADD CONSTRAINT password_reset_tokens_pkey PRIMARY KEY (id);
-- Name: resultados_eurojackpot pk_resultados_eurojackpot; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.resultados_eurojackpot
    ADD CONSTRAINT pk_resultados_eurojackpot PRIMARY KEY (concurso);
-- Name: resultados_lotto_6aus49 pk_resultados_lotto_6aus49; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.resultados_lotto_6aus49
    ADD CONSTRAINT pk_resultados_lotto_6aus49 PRIMARY KEY (concurso);
-- Name: resultados_lotto_fr pk_resultados_lotto_fr; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.resultados_lotto_fr
    ADD CONSTRAINT pk_resultados_lotto_fr PRIMARY KEY (concurso);
-- Name: resultados_thunderball pk_resultados_thunderball; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.resultados_thunderball
    ADD CONSTRAINT pk_resultados_thunderball PRIMARY KEY (concurso);
-- Name: resultados_totoloto pk_resultados_totoloto; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.resultados_totoloto
    ADD CONSTRAINT pk_resultados_totoloto PRIMARY KEY (concurso);
-- Name: posts posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);
-- Name: predicciones_colorloto2 predicciones_colorloto2_fecha_key; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.predicciones_colorloto2
    ADD CONSTRAINT predicciones_colorloto2_fecha_key UNIQUE (fecha);
-- Name: predicciones_colorloto2 predicciones_colorloto2_pkey; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.predicciones_colorloto2
    ADD CONSTRAINT predicciones_colorloto2_pkey PRIMARY KEY (id);
-- Name: predicciones predicciones_pkey1; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.predicciones
    ADD CONSTRAINT predicciones_pkey1 PRIMARY KEY (id);
-- Name: publicidad_calificaciones publicidad_calificaciones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.publicidad_calificaciones
    ADD CONSTRAINT publicidad_calificaciones_pkey PRIMARY KEY (id);
-- Name: publicidad_calificaciones publicidad_calificaciones_publicidad_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.publicidad_calificaciones
    ADD CONSTRAINT publicidad_calificaciones_publicidad_id_user_id_key UNIQUE (publicidad_id, user_id);
-- Name: publicidad publicidad_pkey; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.publicidad
    ADD CONSTRAINT publicidad_pkey PRIMARY KEY (id);
-- Name: transacciones transacciones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.transacciones
    ADD CONSTRAINT transacciones_pkey PRIMARY KEY (id);
-- Name: transacciones transacciones_referencia_key; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.transacciones
    ADD CONSTRAINT transacciones_referencia_key UNIQUE (referencia);
-- Name: predicciones uq_predicciones_loteria_fecha; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.predicciones
    ADD CONSTRAINT uq_predicciones_loteria_fecha UNIQUE (loteria_route, fecha);
-- Name: user_subscriptions user_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.user_subscriptions
    ADD CONSTRAINT user_subscriptions_pkey PRIMARY KEY (id);
-- Name: user_subscriptions user_subscriptions_purchase_token_key; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.user_subscriptions
    ADD CONSTRAINT user_subscriptions_purchase_token_key UNIQUE (purchase_token);
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);
-- Name: idx_5deoro_concurso; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_5deoro_concurso ON public.resultados_5deoro USING btree (concurso);
-- Name: idx_5deoro_loteria_id; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_5deoro_loteria_id ON public.resultados_5deoro USING btree (loteria_id);
-- Name: idx_bloto_concurso; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_bloto_concurso ON public.resultados_bloto USING btree (concurso);
-- Name: idx_bloto_loteria_id; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_bloto_loteria_id ON public.resultados_bloto USING btree (loteria_id);
-- Name: idx_chispazo_fecha; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_chispazo_fecha ON public.resultados_chispazo USING btree (fecha DESC);
-- Name: idx_chispazo_loteria_id; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_chispazo_loteria_id ON public.resultados_chispazo USING btree (loteria_id);
-- Name: idx_comments_post_created_active; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_comments_post_created_active ON public.comments USING btree (post_id, created_at) WHERE ((status)::text = 'active'::text);
-- Name: idx_double_play_concurso; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_double_play_concurso ON public.resultados_double_play USING btree (concurso);
-- Name: idx_double_play_loteria_id; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_double_play_loteria_id ON public.resultados_double_play USING btree (loteria_id);
-- Name: idx_duplasena_concurso; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_duplasena_concurso ON public.resultados_duplasena USING btree (concurso);
-- Name: idx_duplasena_loteria_id; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_duplasena_loteria_id ON public.resultados_duplasena USING btree (loteria_id);
-- Name: idx_email_verification_codes_code; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_email_verification_codes_code ON public.email_verification_codes USING btree (code);
-- Name: idx_email_verification_codes_user; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_email_verification_codes_user ON public.email_verification_codes USING btree (user_id);
-- Name: idx_eurojackpot_fecha; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_eurojackpot_fecha ON public.resultados_eurojackpot USING btree (fecha DESC);
-- Name: idx_eurojackpot_loteria_id; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_eurojackpot_loteria_id ON public.resultados_eurojackpot USING btree (loteria_id);
-- Name: idx_ganadiario_concurso; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_ganadiario_concurso ON public.resultados_ganadiario USING btree (concurso);
-- Name: idx_ganadiario_loteria_id; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_ganadiario_loteria_id ON public.resultados_ganadiario USING btree (loteria_id);
-- Name: idx_jugadas_expira; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_jugadas_expira ON public.jugadas USING btree (expira);
-- Name: idx_jugadas_loteria_id; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_jugadas_loteria_id ON public.jugadas USING btree (loteria_id);
-- Name: idx_jugadas_user_loteria; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_jugadas_user_loteria ON public.jugadas USING btree (user_id, loteria_route);
-- Name: idx_jugadas_user_route; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_jugadas_user_route ON public.jugadas USING btree (user_id, loteria_route);
-- Name: idx_kabala_concurso; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_kabala_concurso ON public.resultados_kabala USING btree (concurso);
-- Name: idx_kabala_loteria_id; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_kabala_loteria_id ON public.resultados_kabala USING btree (loteria_id);
-- Name: idx_latinka_concurso; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_latinka_concurso ON public.resultados_latinka USING btree (concurso);
-- Name: idx_latinka_loteria_id; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_latinka_loteria_id ON public.resultados_latinka USING btree (loteria_id);
-- Name: idx_lotto_6aus49_fecha; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_lotto_6aus49_fecha ON public.resultados_lotto_6aus49 USING btree (fecha DESC);
-- Name: idx_lotto_6aus49_loteria_id; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_lotto_6aus49_loteria_id ON public.resultados_lotto_6aus49 USING btree (loteria_id);
-- Name: idx_lotto_america_concurso; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_lotto_america_concurso ON public.resultados_lotto_america USING btree (concurso);
-- Name: idx_lotto_america_loteria_id; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_lotto_america_loteria_id ON public.resultados_lotto_america USING btree (loteria_id);
-- Name: idx_lotto_fr_fecha; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_lotto_fr_fecha ON public.resultados_lotto_fr USING btree (fecha DESC);
-- Name: idx_lotto_fr_loteria_id; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_lotto_fr_loteria_id ON public.resultados_lotto_fr USING btree (loteria_id);
-- Name: idx_maismilionaria_concurso; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_maismilionaria_concurso ON public.resultados_maismilionaria USING btree (concurso);
-- Name: idx_maismilionaria_loteria_id; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_maismilionaria_loteria_id ON public.resultados_maismilionaria USING btree (loteria_id);
-- Name: idx_megamillions_concurso; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_megamillions_concurso ON public.resultados_megamillions USING btree (concurso);
-- Name: idx_megamillions_loteria_id; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_megamillions_loteria_id ON public.resultados_megamillions USING btree (loteria_id);
-- Name: idx_megasena_concurso; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_megasena_concurso ON public.resultados_megasena USING btree (concurso);
-- Name: idx_megasena_loteria_id; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_megasena_loteria_id ON public.resultados_megasena USING btree (loteria_id);
-- Name: idx_melate_concurso; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_melate_concurso ON public.resultados_melate USING btree (concurso);
-- Name: idx_melate_fecha; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_melate_fecha ON public.resultados_melate USING btree (fecha DESC);
-- Name: idx_melate_loteria_id; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_melate_loteria_id ON public.resultados_melate USING btree (loteria_id);
-- Name: idx_melateretro_concurso; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_melateretro_concurso ON public.resultados_melateretro USING btree (concurso);
-- Name: idx_melateretro_fecha; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_melateretro_fecha ON public.resultados_melateretro USING btree (fecha DESC);
-- Name: idx_melateretro_loteria_id; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_melateretro_loteria_id ON public.resultados_melateretro USING btree (loteria_id);
-- Name: idx_millionaire_life_concurso; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_millionaire_life_concurso ON public.resultados_millionaire_life USING btree (concurso);
-- Name: idx_millionaire_life_loteria_id; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_millionaire_life_loteria_id ON public.resultados_millionaire_life USING btree (loteria_id);
-- Name: idx_mloto_concurso; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_mloto_concurso ON public.resultados_mloto USING btree (concurso);
-- Name: idx_mloto_loteria_id; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_mloto_loteria_id ON public.resultados_mloto USING btree (loteria_id);
-- Name: idx_notification_user_state_visible; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_notification_user_state_visible ON public.notification_user_state USING btree (user_id, eliminado, notification_id);
-- Name: idx_password_reset_tokens_token; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_password_reset_tokens_token ON public.password_reset_tokens USING btree (token);
-- Name: idx_password_reset_tokens_user_id; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_password_reset_tokens_user_id ON public.password_reset_tokens USING btree (user_id);
-- Name: idx_powerball_concurso; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_powerball_concurso ON public.resultados_powerball USING btree (concurso);
-- Name: idx_powerball_loteria_id; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_powerball_loteria_id ON public.resultados_powerball USING btree (loteria_id);
-- Name: idx_predicciones_loteria_id; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_predicciones_loteria_id ON public.predicciones USING btree (loteria_id);
-- Name: idx_predicciones_route_fecha; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_predicciones_route_fecha ON public.predicciones USING btree (loteria_route, fecha DESC);
-- Name: idx_pub_calificaciones_pub_id; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_pub_calificaciones_pub_id ON public.publicidad_calificaciones USING btree (publicidad_id);
-- Name: idx_quina_concurso; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_quina_concurso ON public.resultados_quina USING btree (concurso);
-- Name: idx_quina_loteria_id; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_quina_loteria_id ON public.resultados_quina USING btree (loteria_id);
-- Name: idx_resultados_colorloto2_lot_id; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_resultados_colorloto2_lot_id ON public.resultados_colorloto2 USING btree (loteria_id);
-- Name: idx_resultados_colorloto_lot_id; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_resultados_colorloto_lot_id ON public.resultados_colorloto USING btree (loteria_id);
-- Name: idx_thunderball_fecha; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_thunderball_fecha ON public.resultados_thunderball USING btree (fecha DESC);
-- Name: idx_thunderball_loteria_id; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_thunderball_loteria_id ON public.resultados_thunderball USING btree (loteria_id);
-- Name: idx_totoloto_fecha; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_totoloto_fecha ON public.resultados_totoloto USING btree (fecha DESC);
-- Name: idx_totoloto_loteria_id; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_totoloto_loteria_id ON public.resultados_totoloto USING btree (loteria_id);
-- Name: idx_user_subscriptions_user_id; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_user_subscriptions_user_id ON public.user_subscriptions USING btree (user_id);
-- Name: idx_users_pais_departamento; Type: INDEX; Schema: public; Owner: -
CREATE INDEX idx_users_pais_departamento ON public.users USING btree (pais_id, departamento_id);
-- Name: uq_5deoro_fecha_sorteo; Type: INDEX; Schema: public; Owner: -
CREATE UNIQUE INDEX uq_5deoro_fecha_sorteo ON public.resultados_5deoro USING btree (fecha, sorteo);
-- Name: uq_bloto_fecha_sorteo; Type: INDEX; Schema: public; Owner: -
CREATE UNIQUE INDEX uq_bloto_fecha_sorteo ON public.resultados_bloto USING btree (fecha, sorteo);
-- Name: uq_bonoloto_fecha_sorteo; Type: INDEX; Schema: public; Owner: -
CREATE UNIQUE INDEX uq_bonoloto_fecha_sorteo ON public.resultados_bonoloto USING btree (fecha, sorteo);
-- Name: uq_categorias_nombre; Type: INDEX; Schema: public; Owner: -
CREATE UNIQUE INDEX uq_categorias_nombre ON public.categorias USING btree (lower((nombre)::text));
-- Name: uq_categorias_slug; Type: INDEX; Schema: public; Owner: -
CREATE UNIQUE INDEX uq_categorias_slug ON public.categorias USING btree (slug);
-- Name: uq_colorloto2_fecha_posicion; Type: INDEX; Schema: public; Owner: -
CREATE UNIQUE INDEX uq_colorloto2_fecha_posicion ON public.resultados_colorloto2 USING btree (fecha, posicion);
-- Name: uq_colorloto_fecha; Type: INDEX; Schema: public; Owner: -
CREATE UNIQUE INDEX uq_colorloto_fecha ON public.resultados_colorloto USING btree (fecha);
-- Name: uq_double_play_fecha_sorteo; Type: INDEX; Schema: public; Owner: -
CREATE UNIQUE INDEX uq_double_play_fecha_sorteo ON public.resultados_double_play USING btree (fecha, sorteo);
-- Name: uq_duplasena_fecha_sorteo; Type: INDEX; Schema: public; Owner: -
CREATE UNIQUE INDEX uq_duplasena_fecha_sorteo ON public.resultados_duplasena USING btree (fecha, sorteo);
-- Name: uq_el_gordo_fecha_sorteo; Type: INDEX; Schema: public; Owner: -
CREATE UNIQUE INDEX uq_el_gordo_fecha_sorteo ON public.resultados_el_gordo USING btree (fecha, sorteo);
-- Name: uq_euromillones_fecha_sorteo; Type: INDEX; Schema: public; Owner: -
CREATE UNIQUE INDEX uq_euromillones_fecha_sorteo ON public.resultados_euromillones USING btree (fecha, sorteo);
-- Name: uq_ganadiario_fecha_sorteo; Type: INDEX; Schema: public; Owner: -
CREATE UNIQUE INDEX uq_ganadiario_fecha_sorteo ON public.resultados_ganadiario USING btree (fecha, sorteo);
-- Name: uq_kabala_fecha_sorteo; Type: INDEX; Schema: public; Owner: -
CREATE UNIQUE INDEX uq_kabala_fecha_sorteo ON public.resultados_kabala USING btree (fecha, sorteo);
-- Name: uq_latinka_fecha_sorteo; Type: INDEX; Schema: public; Owner: -
CREATE UNIQUE INDEX uq_latinka_fecha_sorteo ON public.resultados_latinka USING btree (fecha, sorteo);
-- Name: uq_lotto_america_fecha_sorteo; Type: INDEX; Schema: public; Owner: -
CREATE UNIQUE INDEX uq_lotto_america_fecha_sorteo ON public.resultados_lotto_america USING btree (fecha, sorteo);
-- Name: uq_lotto_cr_fecha_sorteo; Type: INDEX; Schema: public; Owner: -
CREATE UNIQUE INDEX uq_lotto_cr_fecha_sorteo ON public.resultados_lotto_cr USING btree (fecha, sorteo);
-- Name: uq_maismilionaria_fecha_sorteo; Type: INDEX; Schema: public; Owner: -
CREATE UNIQUE INDEX uq_maismilionaria_fecha_sorteo ON public.resultados_maismilionaria USING btree (fecha, sorteo);
-- Name: uq_megamillions_fecha_sorteo; Type: INDEX; Schema: public; Owner: -
CREATE UNIQUE INDEX uq_megamillions_fecha_sorteo ON public.resultados_megamillions USING btree (fecha, sorteo);
-- Name: uq_megasena_fecha_sorteo; Type: INDEX; Schema: public; Owner: -
CREATE UNIQUE INDEX uq_megasena_fecha_sorteo ON public.resultados_megasena USING btree (fecha, sorteo);
-- Name: uq_melate_concurso_sorteo; Type: INDEX; Schema: public; Owner: -
CREATE UNIQUE INDEX uq_melate_concurso_sorteo ON public.resultados_melate USING btree (concurso, sorteo);
-- Name: uq_melateretro_concurso; Type: INDEX; Schema: public; Owner: -
CREATE UNIQUE INDEX uq_melateretro_concurso ON public.resultados_melateretro USING btree (concurso);
-- Name: uq_millionaire_life_fecha_sorteo; Type: INDEX; Schema: public; Owner: -
CREATE UNIQUE INDEX uq_millionaire_life_fecha_sorteo ON public.resultados_millionaire_life USING btree (fecha, sorteo);
-- Name: uq_mloto_fecha; Type: INDEX; Schema: public; Owner: -
CREATE UNIQUE INDEX uq_mloto_fecha ON public.resultados_mloto USING btree (fecha);
-- Name: uq_powerball_fecha_sorteo; Type: INDEX; Schema: public; Owner: -
CREATE UNIQUE INDEX uq_powerball_fecha_sorteo ON public.resultados_powerball USING btree (fecha, sorteo);
-- Name: uq_primitiva_fecha_sorteo; Type: INDEX; Schema: public; Owner: -
CREATE UNIQUE INDEX uq_primitiva_fecha_sorteo ON public.resultados_primitiva USING btree (fecha, sorteo);
-- Name: uq_quina_fecha_sorteo; Type: INDEX; Schema: public; Owner: -
CREATE UNIQUE INDEX uq_quina_fecha_sorteo ON public.resultados_quina USING btree (fecha, sorteo);
-- Name: uq_resultados_chispazo_concurso; Type: INDEX; Schema: public; Owner: -
CREATE UNIQUE INDEX uq_resultados_chispazo_concurso ON public.resultados_chispazo USING btree (concurso);
-- Name: uq_user_subscriptions_purchase_token; Type: INDEX; Schema: public; Owner: -
CREATE UNIQUE INDEX uq_user_subscriptions_purchase_token ON public.user_subscriptions USING btree (purchase_token) WHERE (purchase_token IS NOT NULL);
-- Name: categorias trg_categorias_fecha_actualizacion; Type: TRIGGER; Schema: public; Owner: -
CREATE TRIGGER trg_categorias_fecha_actualizacion BEFORE UPDATE ON public.categorias FOR EACH ROW EXECUTE FUNCTION public.actualizar_fecha_modificacion();
-- Name: ciudades ciudades_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.ciudades
    ADD CONSTRAINT ciudades_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id) ON DELETE CASCADE;
-- Name: comments comments_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.comments(id) ON DELETE CASCADE;
-- Name: comments comments_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;
-- Name: comments comments_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;
-- Name: departamentos departamentos_pais_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.departamentos
    ADD CONSTRAINT departamentos_pais_id_fkey FOREIGN KEY (pais_id) REFERENCES public.paises(id);
-- Name: user_subscriptions fk_user_subscriptions_user; Type: FK CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.user_subscriptions
    ADD CONSTRAINT fk_user_subscriptions_user FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;
-- Name: jugadas jugadas_loteria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.jugadas
    ADD CONSTRAINT jugadas_loteria_id_fkey FOREIGN KEY (loteria_id) REFERENCES public.loterias(id) ON DELETE CASCADE;
-- Name: loterias loterias_pais_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.loterias
    ADD CONSTRAINT loterias_pais_id_fkey FOREIGN KEY (pais_id) REFERENCES public.paises(id);
-- Name: notification_user_state notification_user_state_notification_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.notification_user_state
    ADD CONSTRAINT notification_user_state_notification_id_fkey FOREIGN KEY (notification_id) REFERENCES public.notificaciones(id) ON DELETE CASCADE;
-- Name: notification_user_state notification_user_state_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.notification_user_state
    ADD CONSTRAINT notification_user_state_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;
-- Name: password_reset_tokens password_reset_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.password_reset_tokens
    ADD CONSTRAINT password_reset_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;
-- Name: predicciones predicciones_loteria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.predicciones
    ADD CONSTRAINT predicciones_loteria_id_fkey FOREIGN KEY (loteria_id) REFERENCES public.loterias(id) ON DELETE CASCADE;
-- Name: publicidad_calificaciones publicidad_calificaciones_publicidad_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.publicidad_calificaciones
    ADD CONSTRAINT publicidad_calificaciones_publicidad_id_fkey FOREIGN KEY (publicidad_id) REFERENCES public.publicidad(id) ON DELETE CASCADE;
-- Name: publicidad_calificaciones publicidad_calificaciones_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.publicidad_calificaciones
    ADD CONSTRAINT publicidad_calificaciones_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;
-- Name: publicidad publicidad_ciudad_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.publicidad
    ADD CONSTRAINT publicidad_ciudad_id_fkey FOREIGN KEY (ciudad_id) REFERENCES public.ciudades(id);
-- Name: publicidad publicidad_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.publicidad
    ADD CONSTRAINT publicidad_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);
-- Name: publicidad publicidad_pais_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.publicidad
    ADD CONSTRAINT publicidad_pais_id_fkey FOREIGN KEY (pais_id) REFERENCES public.paises(id);
-- Name: publicidad publicidad_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.publicidad
    ADD CONSTRAINT publicidad_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.users(id) ON DELETE CASCADE;
-- Name: resultados_5deoro resultados_5deoro_loteria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.resultados_5deoro
    ADD CONSTRAINT resultados_5deoro_loteria_id_fkey FOREIGN KEY (loteria_id) REFERENCES public.loterias(id);
-- Name: resultados_bloto resultados_bloto_loteria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.resultados_bloto
    ADD CONSTRAINT resultados_bloto_loteria_id_fkey FOREIGN KEY (loteria_id) REFERENCES public.loterias(id);
-- Name: resultados_colorloto2 resultados_colorloto2_loteria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.resultados_colorloto2
    ADD CONSTRAINT resultados_colorloto2_loteria_id_fkey FOREIGN KEY (loteria_id) REFERENCES public.loterias(id);
-- Name: resultados_colorloto resultados_colorloto_loteria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.resultados_colorloto
    ADD CONSTRAINT resultados_colorloto_loteria_id_fkey FOREIGN KEY (loteria_id) REFERENCES public.loterias(id);
-- Name: resultados_double_play resultados_double_play_loteria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.resultados_double_play
    ADD CONSTRAINT resultados_double_play_loteria_id_fkey FOREIGN KEY (loteria_id) REFERENCES public.loterias(id);
-- Name: resultados_eurojackpot resultados_eurojackpot_loteria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.resultados_eurojackpot
    ADD CONSTRAINT resultados_eurojackpot_loteria_id_fkey FOREIGN KEY (loteria_id) REFERENCES public.loterias(id);
-- Name: resultados_lotto_6aus49 resultados_lotto_6aus49_loteria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.resultados_lotto_6aus49
    ADD CONSTRAINT resultados_lotto_6aus49_loteria_id_fkey FOREIGN KEY (loteria_id) REFERENCES public.loterias(id);
-- Name: resultados_lotto_america resultados_lotto_america_loteria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.resultados_lotto_america
    ADD CONSTRAINT resultados_lotto_america_loteria_id_fkey FOREIGN KEY (loteria_id) REFERENCES public.loterias(id);
-- Name: resultados_megamillions resultados_megamillions_loteria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.resultados_megamillions
    ADD CONSTRAINT resultados_megamillions_loteria_id_fkey FOREIGN KEY (loteria_id) REFERENCES public.loterias(id);
-- Name: resultados_millionaire_life resultados_millionaire_life_loteria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.resultados_millionaire_life
    ADD CONSTRAINT resultados_millionaire_life_loteria_id_fkey FOREIGN KEY (loteria_id) REFERENCES public.loterias(id);
-- Name: resultados_mloto resultados_mloto_loteria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.resultados_mloto
    ADD CONSTRAINT resultados_mloto_loteria_id_fkey FOREIGN KEY (loteria_id) REFERENCES public.loterias(id);
-- Name: resultados_powerball resultados_powerball_loteria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.resultados_powerball
    ADD CONSTRAINT resultados_powerball_loteria_id_fkey FOREIGN KEY (loteria_id) REFERENCES public.loterias(id);
-- Name: users users_departamento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_departamento_id_fkey FOREIGN KEY (departamento_id) REFERENCES public.departamentos(id);
-- Name: users users_pais_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pais_id_fkey FOREIGN KEY (pais_id) REFERENCES public.paises(id);
-- Name: categorias; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.categorias ENABLE ROW LEVEL SECURITY;
-- Name: ciudades; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.ciudades ENABLE ROW LEVEL SECURITY;
-- Name: comments; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
-- Name: departamentos; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.departamentos ENABLE ROW LEVEL SECURITY;
-- Name: email_verification_codes; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.email_verification_codes ENABLE ROW LEVEL SECURITY;
-- Name: jugadas; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.jugadas ENABLE ROW LEVEL SECURITY;
-- Name: loterias; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.loterias ENABLE ROW LEVEL SECURITY;
-- Name: loterias_jackpots; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.loterias_jackpots ENABLE ROW LEVEL SECURITY;
-- Name: notificaciones; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.notificaciones ENABLE ROW LEVEL SECURITY;
-- Name: notification_user_state; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.notification_user_state ENABLE ROW LEVEL SECURITY;
-- Name: paises; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.paises ENABLE ROW LEVEL SECURITY;
-- Name: password_reset_tokens; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.password_reset_tokens ENABLE ROW LEVEL SECURITY;
-- Name: posts; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
-- Name: predicciones; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.predicciones ENABLE ROW LEVEL SECURITY;
-- Name: predicciones_colorloto2; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.predicciones_colorloto2 ENABLE ROW LEVEL SECURITY;
-- Name: publicidad; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.publicidad ENABLE ROW LEVEL SECURITY;
-- Name: publicidad_calificaciones; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.publicidad_calificaciones ENABLE ROW LEVEL SECURITY;
-- Name: resultados_5deoro; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.resultados_5deoro ENABLE ROW LEVEL SECURITY;
-- Name: resultados_bloto; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.resultados_bloto ENABLE ROW LEVEL SECURITY;
-- Name: resultados_bonoloto; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.resultados_bonoloto ENABLE ROW LEVEL SECURITY;
-- Name: resultados_chispazo; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.resultados_chispazo ENABLE ROW LEVEL SECURITY;
-- Name: resultados_colorloto; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.resultados_colorloto ENABLE ROW LEVEL SECURITY;
-- Name: resultados_colorloto2; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.resultados_colorloto2 ENABLE ROW LEVEL SECURITY;
-- Name: resultados_double_play; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.resultados_double_play ENABLE ROW LEVEL SECURITY;
-- Name: resultados_duplasena; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.resultados_duplasena ENABLE ROW LEVEL SECURITY;
-- Name: resultados_el_gordo; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.resultados_el_gordo ENABLE ROW LEVEL SECURITY;
-- Name: resultados_eurodreams; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.resultados_eurodreams ENABLE ROW LEVEL SECURITY;
-- Name: resultados_eurojackpot; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.resultados_eurojackpot ENABLE ROW LEVEL SECURITY;
-- Name: resultados_euromillones; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.resultados_euromillones ENABLE ROW LEVEL SECURITY;
-- Name: resultados_ganadiario; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.resultados_ganadiario ENABLE ROW LEVEL SECURITY;
-- Name: resultados_kabala; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.resultados_kabala ENABLE ROW LEVEL SECURITY;
-- Name: resultados_latinka; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.resultados_latinka ENABLE ROW LEVEL SECURITY;
-- Name: resultados_lotto_6aus49; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.resultados_lotto_6aus49 ENABLE ROW LEVEL SECURITY;
-- Name: resultados_lotto_america; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.resultados_lotto_america ENABLE ROW LEVEL SECURITY;
-- Name: resultados_lotto_cr; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.resultados_lotto_cr ENABLE ROW LEVEL SECURITY;
-- Name: resultados_lotto_fr; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.resultados_lotto_fr ENABLE ROW LEVEL SECURITY;
-- Name: resultados_maismilionaria; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.resultados_maismilionaria ENABLE ROW LEVEL SECURITY;
-- Name: resultados_megamillions; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.resultados_megamillions ENABLE ROW LEVEL SECURITY;
-- Name: resultados_megasena; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.resultados_megasena ENABLE ROW LEVEL SECURITY;
-- Name: resultados_melate; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.resultados_melate ENABLE ROW LEVEL SECURITY;
-- Name: resultados_melateretro; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.resultados_melateretro ENABLE ROW LEVEL SECURITY;
-- Name: resultados_millionaire_life; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.resultados_millionaire_life ENABLE ROW LEVEL SECURITY;
-- Name: resultados_mloto; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.resultados_mloto ENABLE ROW LEVEL SECURITY;
-- Name: resultados_powerball; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.resultados_powerball ENABLE ROW LEVEL SECURITY;
-- Name: resultados_primitiva; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.resultados_primitiva ENABLE ROW LEVEL SECURITY;
-- Name: resultados_quina; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.resultados_quina ENABLE ROW LEVEL SECURITY;
-- Name: resultados_thunderball; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.resultados_thunderball ENABLE ROW LEVEL SECURITY;
-- Name: resultados_totoloto; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.resultados_totoloto ENABLE ROW LEVEL SECURITY;
-- Name: transacciones; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.transacciones ENABLE ROW LEVEL SECURITY;
-- Name: user_subscriptions; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.user_subscriptions ENABLE ROW LEVEL SECURITY;
-- Name: user_subscriptions_replay_backup; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.user_subscriptions_replay_backup ENABLE ROW LEVEL SECURITY;
-- Name: users; Type: ROW SECURITY; Schema: public; Owner: -
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
\unrestrict xHREIQF09TD7FZ9LQzjdXYwp3UsXqj2dGo6UD58lrSuimHKzFlIs0b3nemyuKru
